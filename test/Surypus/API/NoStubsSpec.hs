{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.NoStubsSpec (spec) where

import Test.Hspec

spec :: Spec
spec = describe "API handlers" $ do
  let files =
        [ "src/Surypus/API/Goods.hs"
        , "src/Surypus/API/Persons.hs"
        , "src/Surypus/API/Auth.hs"
        ]
      markers = ["stub-token", "QuerySuccess []", "QueryResults [] 0", "QueryError \"Not found\""]

  it "contains no constant stub responses" $ do
    contents <- mapM readFile files
    mapM_ (\marker -> concat contents `shouldNotContain` marker) markers
