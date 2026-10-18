{-# LANGUAGE OverloadedStrings #-}

module Core.DSL.ParserSpec (spec) where

import Test.Hspec
import qualified Data.Aeson as A
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Aeson.Key as K
import qualified Data.Vector as V
import Data.Text (Text)
import qualified Data.Text as T
import Core.DSL.AST
import Core.DSL.Parser

-- Helpers to build JSON values without verbose Aeson plumbing

obj :: [(Text, A.Value)] -> A.Value
obj pairs = A.Object (KM.fromList [(K.fromText k, v) | (k, v) <- pairs])

arr :: [A.Value] -> A.Value
arr vs = A.Array (V.fromList vs)

str :: Text -> A.Value
str = A.String

int :: Int -> A.Value
int = A.Number . fromIntegral

-- Parse a DSL program from a JSON value
parseEither :: A.Value -> Either Text DSLProgram
parseEither = parseDSL

spec :: Spec
spec = describe "Core.DSL.Parser" $ do

  describe "parseDSL — root structure" $ do
    it "parses an empty program (no entities, enums, apis)" $ do
      let result = parseEither (obj [])
      result `shouldBe` Right (DSLProgram [] [] [])

    it "parses a program with empty entity/enum/api arrays" $ do
      let result = parseEither (obj
            [ ("entities", arr [])
            , ("enums",    arr [])
            , ("apis",     arr [])
            ])
      result `shouldBe` Right (DSLProgram [] [] [])

    it "rejects a non-object root (string)" $ do
      let result = parseEither (str "not-an-object")
      case result of
        Left msg -> msg `shouldBe` "DSL root must be a JSON object"
        Right _  -> expectationFailure "expected Left for non-object root"

    it "rejects a non-object root (array)" $ do
      let result = parseEither (arr [obj [("name", str "x")]])
      case result of
        Left msg -> msg `shouldBe` "DSL root must be a JSON object"
        Right _  -> expectationFailure "expected Left for non-object root"

    it "rejects a non-object root (number)" $ do
      let result = parseEither (int 42)
      case result of
        Left msg -> msg `shouldBe` "DSL root must be a JSON object"
        Right _  -> expectationFailure "expected Left for non-object root"

  describe "parseDSL — entities" $ do
    it "parses a single entity with one field" $ do
      let json = obj
            [ ("entities", arr
                [ obj
                    [ ("name", str "User")
                    , ("fields", arr
                        [ obj
                            [ ("name", str "email")
                            , ("type", str "text")
                            , ("nullable", A.Bool False)
                            ]
                        ])
                    , ("primaryKey", str "id")
                    ]
                ])
            ]
      let expected = DSLProgram
            { dpEntities = [ EntityDef
                { eName    = "User"
                , eTable   = Nothing
                , eFields  = [ FieldDef
                    { fdName     = "email"
                    , fdType     = FTText
                    , fdNullable = False
                    , fdDefault  = Nothing
                    , fdRelation = Nothing
                    , fdIsId     = False
                    }]
                , ePrimary = Just "id"
                , eUniques = []
                , eIndexes = []
                }]
            , dpEnums = []
            , dpAPIs  = []
            }
      parseEither json `shouldBe` Right expected

    it "parses multiple entities" $ do
      let json = obj
            [ ("entities", arr
                [ obj [("name", str "A"), ("fields", arr [])]
                , obj [("name", str "B"), ("fields", arr [])]
                ]
                )
            ]
      case parseEither json of
        Right prog -> length (dpEntities prog) `shouldBe` 2
        Left err   -> expectationFailure ("unexpected parse error: " ++ T.unpack err)

    it "defaults eTable, eUniques, eIndexes to empty" $ do
      let json = obj
            [ ("entities", arr
                [ obj [("name", str "X"), ("fields", arr [])]
                ]
                )
            ]
      case parseEither json of
        Right (DSLProgram [e] _ _) -> do
          eTable e   `shouldBe` Nothing
          eUniques e `shouldBe` []
          eIndexes e `shouldBe` []
        _ -> expectationFailure "unexpected parse result"

  describe "parseDSL — enums" $ do
    it "parses an enum with string values" $ do
      let json = obj
            [ ("enums", arr
                [ obj
                    [ ("name", str "Status")
                    , ("values", arr [str "active", str "inactive"])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ [e] _) -> do
          edName e   `shouldBe` "Status"
          edValues e `shouldBe` ["active", "inactive"]
        _ -> expectationFailure "unexpected parse result"

    it "rejects enum values that are not strings" $ do
      let json = obj
            [ ("enums", arr
                [ obj
                    [ ("name", str "Status")
                    , ("values", arr [str "active", int 42])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for non-string enum value"

    it "rejects enum without values array" $ do
      let json = obj
            [ ("enums", arr [obj [("name", str "Status")]])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing values"

  describe "parseDSL — field types" $ do
    let parseFieldT :: Text -> Either Text FieldType
        parseFieldT t = case parseDSL (obj
              [ ("entities", arr
                  [ obj
                      [ ("name", str "E")
                      , ("fields", arr
                          [ obj
                              [ ("name", str "f")
                              , ("type", str t)
                              ]
                          ])
                      ]
                  ])
              ]) of
          Right (DSLProgram [e] _ _) -> Right (fdType (head (eFields e)))
          Left err                -> Left err
          _                       -> Left "unexpected parse result"

    it "parses 'text'" $ do
      parseFieldT "text" `shouldBe` Right FTText

    it "parses 'string' as FTText" $ do
      parseFieldT "string" `shouldBe` Right FTText

    it "parses 'int'" $ do
      parseFieldT "int" `shouldBe` Right FTInt

    it "parses 'double'" $ do
      parseFieldT "double" `shouldBe` Right FTDouble

    it "parses 'bool'" $ do
      parseFieldT "bool" `shouldBe` Right FTBool

    it "parses 'date'" $ do
      parseFieldT "date" `shouldBe` Right FTDate

    it "parses 'datetime'" $ do
      parseFieldT "datetime" `shouldBe` Right FTDateTime

    it "parses 'json'" $ do
      parseFieldT "json" `shouldBe` Right FTJSON

    it "parses 'bytes'" $ do
      parseFieldT "bytes" `shouldBe` Right FTBytes

    it "parses 'uuid'" $ do
      parseFieldT "uuid" `shouldBe` Right FTUUID

    it "parses 'list:int'" $ do
      parseFieldT "list:int" `shouldBe` Right (FTList FTInt)

    it "parses 'list:text'" $ do
      parseFieldT "list:text" `shouldBe` Right (FTList FTText)

    it "parses 'ref:User'" $ do
      parseFieldT "ref:User" `shouldBe` Right (FTReference "User")

    it "parses 'enum:Status'" $ do
      parseFieldT "enum:Status" `shouldBe` Right (FTEnum "Status")

    it "rejects unknown type" $ do
      parseFieldT "unknown" `shouldBe` Left "Unknown field type: unknown"

    it "rejects 'list:' with unknown inner type" $ do
      parseFieldT "list:unknown" `shouldBe` Left "Unknown field type: unknown"

  describe "parseDSL — nullable" $ do
    it "parses nullable=true" $ do
      let json = obj
            [ ("entities", arr
                [ obj
                    [ ("name", str "E")
                    , ("fields", arr
                        [ obj
                            [ ("name", str "f")
                            , ("type", str "text")
                            , ("nullable", A.Bool True)
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram [e] _ _) -> do
          fdNullable (head (eFields e)) `shouldBe` True
        _ -> expectationFailure "unexpected parse result"

    it "parses nullable=false" $ do
      let json = obj
            [ ("entities", arr
                [ obj
                    [ ("name", str "E")
                    , ("fields", arr
                        [ obj
                            [ ("name", str "f")
                            , ("type", str "text")
                            , ("nullable", A.Bool False)
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram [e] _ _) -> do
          fdNullable (head (eFields e)) `shouldBe` False
        _ -> expectationFailure "unexpected parse result"

    it "defaults nullable to false when missing" $ do
      let json = obj
            [ ("entities", arr
                [ obj
                    [ ("name", str "E")
                    , ("fields", arr
                        [ obj
                            [ ("name", str "f")
                            , ("type", str "text")
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram [e] _ _) -> do
          fdNullable (head (eFields e)) `shouldBe` False
        _ -> expectationFailure "unexpected parse result"

  describe "parseDSL — APIs and operations" $ do
    it "parses an API with one GET operation" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "UserAPI")
                    , ("entity", str "User")
                    , ("operations", arr
                        [ obj
                            [ ("name", str "getUser")
                            , ("method", str "GET")
                            , ("path", str "/users/{id}")
                            , ("filters", arr [])
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          aName api       `shouldBe` "UserAPI"
          aEntity api     `shouldBe` "User"
          length (aOperations api) `shouldBe` 1
          let op = head (aOperations api)
          odName op   `shouldBe` "getUser"
          odMethod op `shouldBe` GET
          odPath op   `shouldBe` "/users/{id}"
          odAuth op    `shouldBe` True
        _ -> expectationFailure "unexpected parse result"

    it "parses POST method" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj [("name", str "op"), ("method", str "POST"), ("path", str "/x")]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          odMethod (head (aOperations api)) `shouldBe` POST
        _ -> expectationFailure "unexpected parse result"

    it "parses PUT method" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj [("name", str "op"), ("method", str "PUT"), ("path", str "/x")]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          odMethod (head (aOperations api)) `shouldBe` PUT
        _ -> expectationFailure "unexpected parse result"

    it "parses PATCH method" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj [("name", str "op"), ("method", str "PATCH"), ("path", str "/x")]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          odMethod (head (aOperations api)) `shouldBe` PATCH
        _ -> expectationFailure "unexpected parse result"

    it "parses DELETE method" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj [("name", str "op"), ("method", str "DELETE"), ("path", str "/x")]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          odMethod (head (aOperations api)) `shouldBe` DELETE
        _ -> expectationFailure "unexpected parse result"

    it "defaults to GET when method is missing" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj [("name", str "op"), ("path", str "/x")]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          odMethod (head (aOperations api)) `shouldBe` GET
        _ -> expectationFailure "unexpected parse result"

    it "rejects unknown HTTP method" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj [("name", str "op"), ("method", str "TRACE"), ("path", str "/x")]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for unknown method"

  describe "parseDSL — filters" $ do
    it "parses a filter with eq operator" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj
                            [ ("name", str "op")
                            , ("method", str "GET")
                            , ("path", str "/x")
                            , ("filters", arr
                                [ obj
                                    [ ("field", str "status")
                                    , ("op", str "eq")
                                    , ("value", str "active")
                                    ]
                                ])
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          let op = head (aOperations api)
          length (odFilters op) `shouldBe` 1
          let fl = head (odFilters op)
          flField    fl `shouldBe` "status"
          flOperator fl `shouldBe` Eq
          flValue    fl `shouldBe` A.String "active"
        _ -> expectationFailure "unexpected parse result"

    it "parses all filter operators" $ do
      let ops = ["eq", "neq", "gt", "gte", "lt", "lte", "in", "notIn", "like", "iLike", "isNull", "notNull"]
          expectedOps = [Eq, Neq, Gt, Gte, Lt, Lte, In, NotIn, Like, ILike, IsNull, IsNotNull]
      mapM_ (\(opStr, expected) -> do
        let json = obj
              [ ("apis", arr
                  [ obj
                      [ ("name", str "A")
                      , ("entity", str "E")
                      , ("operations", arr
                          [ obj
                              [ ("name", str "op")
                              , ("method", str "GET")
                              , ("path", str "/x")
                              , ("filters", arr
                                  [ obj [("field", str "f"), ("op", str opStr)]
                                  ])
                              ]
                          ])
                      ]
                  ])
              ]
        case parseEither json of
          Right (DSLProgram _ _ [api]) -> do
            flOperator (head (odFilters (head (aOperations api)))) `shouldBe` expected
          _ -> expectationFailure ("unexpected parse for op: " ++ T.unpack opStr)
        ) (zip ops expectedOps)

    it "rejects unknown filter operator" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj
                            [ ("name", str "op")
                            , ("method", str "GET")
                            , ("path", str "/x")
                            , ("filters", arr
                                [ obj [("field", str "f"), ("op", str "unknownOp")]
                                ])
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for unknown filter op"

    it "defaults filter value to empty string when missing" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr
                        [ obj
                            [ ("name", str "op")
                            , ("method", str "GET")
                            , ("path", str "/x")
                            , ("filters", arr
                                [ obj [("field", str "f"), ("op", str "eq")]
                                ])
                            ]
                        ])
                    ]
                ])
            ]
      case parseEither json of
        Right (DSLProgram _ _ [api]) -> do
          flValue (head (odFilters (head (aOperations api)))) `shouldBe` A.String ""
        _ -> expectationFailure "unexpected parse result"

  describe "parseDSL — error cases" $ do
    it "rejects entity without name" $ do
      let json = obj
            [ ("entities", arr [obj [("fields", arr [])]])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing entity name"

    it "rejects entity with non-object" $ do
      let json = obj
            [ ("entities", arr [str "not-an-object"])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for non-object entity"

    it "rejects field without name" $ do
      let json = obj
            [ ("entities", arr
                [ obj
                    [ ("name", str "E")
                    , ("fields", arr [obj [("type", str "text")]])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing field name"

    it "rejects field without type" $ do
      let json = obj
            [ ("entities", arr
                [ obj
                    [ ("name", str "E")
                    , ("fields", arr [obj [("name", str "f")]])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing field type"

    it "rejects API without name" $ do
      let json = obj
            [ ("apis", arr [obj [("entity", str "E"), ("operations", arr [])]])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing API name"

    it "rejects API without entity" $ do
      let json = obj
            [ ("apis", arr [obj [("name", str "A"), ("operations", arr [])]])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing API entity"

    it "rejects operation without name" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr [obj [("method", str "GET"), ("path", str "/x")]])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing operation name"

    it "rejects operation without path" $ do
      let json = obj
            [ ("apis", arr
                [ obj
                    [ ("name", str "A")
                    , ("entity", str "E")
                    , ("operations", arr [obj [("name", str "op"), ("method", str "GET")]])
                    ]
                ])
            ]
      case parseEither json of
        Left _  -> pure ()
        Right _ -> expectationFailure "expected Left for missing operation path"