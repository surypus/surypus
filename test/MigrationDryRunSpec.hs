{-# LANGUAGE OverloadedStrings #-}
module MigrationDryRunSpec (spec) where

import Test.Hspec
import qualified Surypus.Domain.RBACCanon.Migration as M

spec :: Spec
spec = do
  describe "MigrationDryRun" $ do
    it "V001..V028 are non-empty" $ do
      mapM_ (\f -> f `shouldSatisfy` (not . null))
        [ M.generateV001, M.generateV002, M.generateV003, M.generateV004, M.generateV005, M.generateV006
        , M.generateV007, M.generateV008, M.generateV009, M.generateV010, M.generateV011, M.generateV012
        , M.generateV013, M.generateV014, M.generateV015, M.generateV016, M.generateV017, M.generateV018
        , M.generateV019, M.generateV020, M.generateV021, M.generateV022, M.generateV023, M.generateV024
        , M.generateV025, M.generateV026, M.generateV027, M.generateV028
        ]
