{-# LANGUAGE OverloadedStrings #-}

module Core.DSL.Parser
  ( parseDSL, parseDSLFile, parseDSLText
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (Value(Object, Array, String))
import qualified Data.Aeson as A
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Aeson.Key as K
import qualified Data.ByteString.Lazy as BL
import Core.DSL.AST

parseDSL :: A.Value -> Either Text DSLProgram
parseDSL (Object o) = do
  entities <- mapM parseEntityDef =<< parseList o "entities"
  enums    <- mapM parseEnumDef =<< parseList o "enums" :: Either Text [EnumDef]
  apis     <- mapM parseAPIDef =<< parseList o "apis"
  pure DSLProgram
    { dpEntities = entities
    , dpEnums    = enums
    , dpAPIs     = apis
    }
parseDSL _ = Left "DSL root must be a JSON object"

parseDSLFile :: FilePath -> IO (Either Text DSLProgram)
parseDSLFile path = do
  content <- BL.readFile path
  case A.eitherDecode content of
    Left err  -> pure $ Left $ T.pack err
    Right val -> pure $ parseDSL val

parseDSLText :: Text -> IO (Either Text DSLProgram)
parseDSLText txt = parseDSLFile (T.unpack txt)

parseList :: KM.KeyMap A.Value -> K.Key -> Either Text [A.Value]
parseList o key = case KM.lookup key o of
  Just (Array arr) -> Right (foldr (:) [] arr)
  Just _           -> Left $ "Expected array for key: " <> K.toText key
  Nothing          -> Right []

parseEntityDef :: A.Value -> Either Text EntityDef
parseEntityDef (Object o) = do
  name    <- parseField o "name"
  fields  <- mapM parseFieldDef =<< parseList o "fields"
  primary <- parseMaybeField o "primaryKey"
  pure EntityDef
    { eName     = name
    , eTable    = Nothing
    , eFields   = fields
    , ePrimary  = primary
    , eUniques  = []
    , eIndexes  = []
    }
parseEntityDef _ = Left "Entity def must be an object"

parseEnumDef :: A.Value -> Either Text EnumDef
parseEnumDef (Object o) = do
  name   <- parseField o "name"
  rawArr <- case KM.lookup "values" o of
    Just (Array arr) -> Right (map valueToText (foldr (: ) [] arr))
    _                -> Left "enum values must be array"
  values <- mapM (either Left Right) rawArr
  pure EnumDef { edName = name, edValues = values }
  where
    valueToText :: A.Value -> Either Text Text
    valueToText (A.String t) = Right t
    valueToText _ = Left "enum values must be strings"
parseEnumDef _ = Left "Enum def must be an object"

parseFieldDef :: A.Value -> Either Text FieldDef
parseFieldDef (Object o) = do
  name     <- parseField o "name"
  typeName <- parseField o "type" :: Either Text Text
  ftype    <- parseFieldType typeName
  nullable <- do
    r <- parseMaybeField o "nullable" :: Either Text (Maybe A.Value)
    case r of
      Just _  -> Right True
      Nothing -> Right False
  pure FieldDef
    { fdName     = name
    , fdType     = ftype
    , fdNullable = nullable
    , fdDefault  = Nothing
    , fdRelation = Nothing
    , fdIsId     = False
    }
parseFieldDef _ = Left "Field def must be an object"

parseFieldType :: Text -> Either Text FieldType
parseFieldType "text"     = Right FTText
parseFieldType "int"      = Right FTInt
parseFieldType "double"   = Right FTDouble
parseFieldType "bool"     = Right FTBool
parseFieldType "date"     = Right FTDate
parseFieldType "datetime" = Right FTDateTime
parseFieldType "json"     = Right FTJSON
parseFieldType "bytes"    = Right FTBytes
parseFieldType "uuid"     = Right FTUUID
parseFieldType "string"   = Right FTText
parseFieldType t
  | "list:" `T.isPrefixOf` t = fmap FTList (parseFieldType (T.drop 5 t))
  | "ref:" `T.isPrefixOf` t = Right $ FTReference (T.drop 4 t)
  | "enum:" `T.isPrefixOf` t = Right $ FTEnum (T.drop 5 t)
  | otherwise = Left $ "Unknown field type: " <> t

parseAPIDef :: A.Value -> Either Text APIDef
parseAPIDef (Object o) = do
  name       <- parseField o "name"
  entity     <- parseField o "entity"
  operations <- mapM parseOpDef =<< parseList o "operations"
  pure APIDef
    { aName       = name
    , aEntity     = entity
    , aOperations = operations
    }
parseAPIDef _ = Left "API def must be an object"

parseOpDef :: A.Value -> Either Text OpDef
parseOpDef (Object o) = do
  name   <- parseField o "name"
  method <- parseMethod o
  path   <- parseField o "path"
  filters <- mapM parseFilterDef =<< parseList o "filters"
  pure OpDef
    { odName    = name
    , odMethod  = method
    , odPath    = path
    , odQuery   = QueryDef [] name Nothing [] [] [] Nothing Nothing
    , odAuth    = True
    , odFilters = filters
    , odFields  = []
    }
parseOpDef _ = Left "Operation def must be an object"

parseMethod :: KM.KeyMap A.Value -> Either Text HTTPMethod
parseMethod o = case KM.lookup "method" o of
  Just (String "GET")    -> Right GET
  Just (String "POST")   -> Right POST
  Just (String "PUT")    -> Right PUT
  Just (String "PATCH")  -> Right PATCH
  Just (String "DELETE") -> Right DELETE
  Just (String s)        -> Left $ "Unknown HTTP method: " <> s
  _                      -> Right GET

parseFilterDef :: A.Value -> Either Text FilterDef
parseFilterDef (Object o) = do
  field <- parseField o "field"
  op    <- parseFilterOp =<< parseField o "op"
  value <- case KM.lookup "value" o of
    Just v  -> Right v
    Nothing -> Right (String "")
  pure FilterDef
    { flField    = field
    , flOperator = op
    , flValue    = value
    }
parseFilterDef _ = Left "Filter def must be an object"

parseFilterOp :: Text -> Either Text FilterOp
parseFilterOp "eq"       = Right Eq
parseFilterOp "neq"      = Right Neq
parseFilterOp "gt"       = Right Gt
parseFilterOp "gte"      = Right Gte
parseFilterOp "lt"       = Right Lt
parseFilterOp "lte"      = Right Lte
parseFilterOp "in"       = Right In
parseFilterOp "notIn"    = Right NotIn
parseFilterOp "like"     = Right Like
parseFilterOp "iLike"    = Right ILike
parseFilterOp "isNull"   = Right IsNull
parseFilterOp "notNull"  = Right IsNotNull
parseFilterOp s          = Left $ "Unknown filter op: " <> s

parseField :: A.FromJSON a => KM.KeyMap A.Value -> K.Key -> Either Text a
parseField o key = case KM.lookup key o of
  Just v  -> case A.fromJSON v of
    A.Success a -> Right a
    A.Error e   -> Left $ T.pack e
  Nothing -> Left $ "Missing field: " <> K.toText key

parseMaybeField :: A.FromJSON a => KM.KeyMap A.Value -> K.Key -> Either Text (Maybe a)
parseMaybeField o key = case KM.lookup key o of
  Just v  -> case A.fromJSON v of
    A.Success a -> Right (Just a)
    A.Error _   -> Right Nothing
  Nothing -> Right Nothing
