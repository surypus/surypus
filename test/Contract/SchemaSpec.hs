{-# LANGUAGE OverloadedStrings #-}
module Contract.SchemaSpec (spec) where

import Test.Hspec
import Data.Yaml (decodeFileEither, ParseException)
import Data.Text (Text)
import Data.Aeson (FromJSON (..), withObject, (.:))

-- | Typed view of the dsl/schema.yaml contract. A field lacking
-- "name" or "type" fails to decode, so a successful typed decode
-- proves every field carries both keys.
data Schema = Schema
  { schemaVersion :: Text
  , schemaEntities :: [Entity]
  } deriving (Show, Eq)

instance FromJSON Schema where
  parseJSON = withObject "Schema" $ \o ->
    Schema <$> o .: "version" <*> o .: "entities"

data Entity = Entity
  { entityName :: Text
  , entityFields :: [Field]
  } deriving (Show, Eq)

instance FromJSON Entity where
  parseJSON = withObject "Entity" $ \o ->
    Entity <$> o .: "name" <*> o .: "fields"

data Field = Field
  { fieldName :: Text
  , fieldType :: Text
  } deriving (Show, Eq)

instance FromJSON Field where
  parseJSON = withObject "Field" $ \o ->
    Field <$> o .: "name" <*> o .: "type"

-- | Load and validate the domain schema
main :: IO ()
main = hspec spec

spec :: Spec
spec = describe "dsl/schema.yaml contract validation" $ do
  it "loads schema.yaml without errors" $ do
    result <- decodeFileEither "dsl/schema.yaml" :: IO (Either ParseException Schema)
    result `shouldSatisfy` either (const False) (const True)

  it "has a version field" $ do
    schema <- loadSchema
    schemaVersion schema `shouldBe` "1.0.0"

  it "has entities defined" $ do
    schema <- loadSchema
    schemaEntities schema `shouldSatisfy` (not . null)

  it "all entity names are unique" $ do
    schema <- loadSchema
    let names = map entityName (schemaEntities schema)
    length names `shouldBe` length (nub names)

  it "all fields have a name and type" $ do
    schema <- loadSchema
    let fields = concatMap entityFields (schemaEntities schema)
    -- the typed decode above already enforces name+type on every
    -- field; this guards against a vacuous pass on an empty schema
    fields `shouldSatisfy` (not . null)

loadSchema :: IO Schema
loadSchema = do
  result <- decodeFileEither "dsl/schema.yaml" :: IO (Either ParseException Schema)
  case result of
    Right schema -> pure schema
    Left err -> do
      expectationFailure ("schema.yaml failed to decode: " ++ show err)
      fail "unreachable"

nub :: Eq a => [a] -> [a]
nub = foldr (\x acc -> if x `elem` acc then acc else x:acc) []
