module Test.SurypusSpec where

import Test.Hspec
import qualified DAL.TypesSpec
import qualified DAL.DBSpec
import qualified API.Integration.RESTSpec
import qualified API.ServerSpec

main :: IO ()
main = hspec $ do
  describe "DAL Layer Tests" $ do
    describe "DAL.Types" DAL.TypesSpec.spec
    describe "DAL.DB" DAL.DBSpec.spec
  describe "API Integration Tests" $ do
    describe "API.Integration.REST" API.Integration.RESTSpec.spec
  describe "API Server Tests" $ do
    describe "API.Server" API.ServerSpec.spec
