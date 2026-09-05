{-# LANGUAGE DeriveGeneric #-}

module Core.DSL.AST where

import Data.Text (Text)
import GHC.Generics (Generic)
import Data.Aeson (Value)

data DSLProgram = DSLProgram
  { dpEntities :: [EntityDef]
  , dpEnums    :: [EnumDef]
  , dpAPIs     :: [APIDef]
  } deriving (Show, Eq, Generic)

data EnumDef = EnumDef
  { edName   :: Text
  , edValues :: [Text]
  } deriving (Show, Eq, Generic)

data EntityDef = EntityDef
  { eName     :: Text
  , eTable    :: Maybe Text
  , eFields   :: [FieldDef]
  , ePrimary  :: Maybe Text
  , eUniques  :: [[Text]]
  , eIndexes  :: [[Text]]
  } deriving (Show, Eq, Generic)

data FieldDef = FieldDef
  { fdName     :: Text
  , fdType     :: FieldType
  , fdNullable :: Bool
  , fdDefault  :: Maybe Value
  , fdRelation :: Maybe Text
  , fdIsId     :: Bool
  } deriving (Show, Eq, Generic)

data FieldType
  = FTText
  | FTInt
  | FTDouble
  | FTBool
  | FTDate
  | FTDateTime
  | FTEnum Text
  | FTReference Text
  | FTJSON
  | FTBytes
  | FTUUID
  | FTList FieldType
  deriving (Show, Eq, Generic)

data RelationDef = RelationDef
  { rdTarget   :: Text
  , rdField    :: Text
  , rdOnDelete :: CascadeAction
  , rdOnUpdate :: CascadeAction
  } deriving (Show, Eq, Generic)

data CascadeAction = Cascade | Restrict | SetNull | NoAction
  deriving (Show, Eq, Generic)

data APIDef = APIDef
  { aName        :: Text
  , aEntity      :: Text
  , aOperations  :: [OpDef]
  } deriving (Show, Eq, Generic)

data OpDef = OpDef
  { odName    :: Text
  , odMethod  :: HTTPMethod
  , odPath    :: Text
  , odQuery   :: QueryDef
  , odAuth    :: Bool
  , odFilters :: [FilterDef]
  , odFields  :: [Text]
  } deriving (Show, Eq, Generic)

data HTTPMethod = GET | POST | PUT | PATCH | DELETE
  deriving (Show, Eq, Generic)

data QueryDef = QueryDef
  { qdSelect   :: [Text]
  , qdFrom     :: Text
  , qdWhere    :: Maybe Value
  , qdJoin     :: [JoinDef]
  , qdGroupBy  :: [Text]
  , qdOrderBy  :: [(Text, OrderDir)]
  , qdLimit    :: Maybe Int
  , qdOffset   :: Maybe Int
  } deriving (Show, Eq, Generic)

data JoinDef = JoinDef
  { jdTarget  :: Text
  , jdOn      :: (Text, Text)
  , jdType    :: JoinType
  } deriving (Show, Eq, Generic)

data JoinType = InnerJoin | LeftJoin | RightJoin
  deriving (Show, Eq, Generic)

data OrderDir = ASC | DESC
  deriving (Show, Eq, Generic)

data FilterDef = FilterDef
  { flField    :: Text
  , flOperator :: FilterOp
  , flValue    :: Value
  } deriving (Show, Eq, Generic)

data FilterOp
  = Eq | Neq | Gt | Gte | Lt | Lte
  | In | NotIn | Like | ILike
  | IsNull | IsNotNull
  deriving (Show, Eq, Generic)
