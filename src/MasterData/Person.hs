-- Master Data: Person (counterpart/customer) module — Phase 4.
module MasterData.Person (Person(..), personName) where

data Person = Person
  { personId   :: Int
  , personName :: String
  , personType :: String  -- "customer" | "supplier"
  } deriving (Eq, Show)
