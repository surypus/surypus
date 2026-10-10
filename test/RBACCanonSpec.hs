{-# LANGUAGE OverloadedStrings #-}
module RBACCanonSpec (spec) where

import Test.Hspec
import qualified Data.Text as T
import qualified Surypus.Domain.RBACCanon.Types as RT
import qualified Surypus.Domain.RBACCanon.Migration as M
import qualified Surypus.Infra.SqlGen.DSL as DSL
import Data.List (isInfixOf)

spec :: Spec
spec = do
  describe "RBACCanon.Types" $ do
    it "mkCanon sets name" $ do
      let name = T.pack "example"
          canon = RT.mkCanon name
      RT.cName canon `shouldBe` name
  describe "RBACCanon.Migrations" $ do
    it "generateV001 is non-empty" $ do
      M.generateV001 `shouldSatisfy` (not . null)
    it "generateV019 is non-empty" $ do
      M.generateV019 `shouldSatisfy` (not . null)
    it "generateV020 has CREATE VIEW" $ do
      M.generateV020 `shouldSatisfy` (isInfixOf "CREATE VIEW")
    it "generateV021 uses UNIQUE constraints" $ do
      M.generateV021 `shouldSatisfy` (isInfixOf "UNIQUE (name, owner_id)")
    it "DSL helpers render correctly" $ do
      DSL.render (DSL.dropTable "t1") `shouldBe` "DROP TABLE IF EXISTS t1;"
      DSL.render (DSL.renameTable "old" "new") `shouldBe` "ALTER TABLE old RENAME TO new;"
      DSL.render (DSL.addConstraint "t1" "cons1" "FOREIGN KEY (c) REFERENCES other(id)") `shouldBe` "ALTER TABLE t1 ADD CONSTRAINT cons1 FOREIGN KEY (c) REFERENCES other(id);"
      DSL.render (DSL.dropConstraint "t1" "cons1") `shouldBe` "ALTER TABLE t1 DROP CONSTRAINT cons1;"
    it "V025–V028 content checks" $ do
      M.generateV025 `shouldSatisfy` (isInfixOf "idx_rbac_canon_updated_at")
      M.generateV026 `shouldSatisfy` (isInfixOf "CREATE VIEW v_rbac_canon_log_summary2")
      M.generateV027 `shouldSatisfy` (isInfixOf "ck_rbac_canon_name")
      M.generateV028 `shouldSatisfy` (isInfixOf "v_rbac_canon_full_summary2")
    it "V023 adds notes" $ do
      M.generateV023 `shouldSatisfy` (isInfixOf "notes")
    it "V024 adds notes2" $ do
      M.generateV024 `shouldSatisfy` (isInfixOf "notes2")
