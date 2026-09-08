{-# LANGUAGE OverloadedStrings #-}
module Surypus.App.Main where

import Surypus.Domain.RBACCanon.Migration as RBACMigration
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

main :: IO ()
main = do
  putStrLn "Surypus RBACCanon skeleton loaded"
  let v001 = RBACMigration.generateV001
  let v002 = RBACMigration.generateV002
  let v003 = RBACMigration.generateV003
  let v004 = RBACMigration.generateV004
  let v005 = RBACMigration.generateV005
  let v006 = RBACMigration.generateV006
  let v007 = RBACMigration.generateV007
  let v008 = RBACMigration.generateV008
  let v009 = RBACMigration.generateV009
  let v010 = RBACMigration.generateV010
  let v011 = RBACMigration.generateV011
  let v012 = RBACMigration.generateV012
  let v013 = RBACMigration.generateV013
  let v014 = RBACMigration.generateV014
  let v015 = RBACMigration.generateV015
  let v016 = RBACMigration.generateV016
  let v017 = RBACMigration.generateV017
  let v018 = RBACMigration.generateV018
  -- (V019..V024) declarations continued above
  let v019 = RBACMigration.generateV019
  let v020 = RBACMigration.generateV020
  let v021 = RBACMigration.generateV021
  let v022 = RBACMigration.generateV022
  let v023 = RBACMigration.generateV023
  let v024 = RBACMigration.generateV024
  let v025 = RBACMigration.generateV025
  let v026 = RBACMigration.generateV026
  let v027 = RBACMigration.generateV027
  let v028 = RBACMigration.generateV028
  putStrLn "--- Generated V001 migration (DSL) ---"
  putStrLn v001
  -- Emit generated migration to SQL file (for quick iteration)
  let outDir = "sql/migrations"
  createDirectoryIfMissing True outDir
  let outPath = outDir </> "V001__rbac_basic_schema.generated.sql"
  writeFile outPath v001
  putStrLn $ "Wrote generated migration to: " ++ outPath

  -- Generate and persist additional migrations as part of the same startup
  let outPath2 = outDir </> "V002__rbac_indexes.generated.sql"
  writeFile outPath2 v002
  putStrLn $ "Wrote generated migration to: " ++ outPath2

  let outPath3 = outDir </> "V003__rbac_updated_at.generated.sql"
  writeFile outPath3 v003
  putStrLn $ "Wrote generated migration to: " ++ outPath3

  -- Persist V004 migration
  let outPath4 = outDir </> "V004__rbac_description.generated.sql"
  writeFile outPath4 v004
  putStrLn $ "Wrote generated migration to: " ++ outPath4

  -- Persist V005 migration
  let outPath5 = outDir </> "V005__rbac_active.generated.sql"
  writeFile outPath5 v005
  putStrLn $ "Wrote generated migration to: " ++ outPath5

  -- Persist V006 migration
  let outPath6 = outDir </> "V006__rbac_security_level.generated.sql"
  writeFile outPath6 v006
  putStrLn $ "Wrote generated migration to: " ++ outPath6

  -- Persist V007 migration
  let outPath7 = outDir </> "V007__rbac_owner_id.generated.sql"
  writeFile outPath7 v007
  putStrLn $ "Wrote generated migration to: " ++ outPath7

  -- Persist V008 migration
  let outPath8 = outDir </> "V008__rbac_created_by.generated.sql"
  writeFile outPath8 v008
  putStrLn $ "Wrote generated migration to: " ++ outPath8

  -- Persist V009 migration
  let outPath9 = outDir </> "V009__rbac_updated_by.generated.sql"
  writeFile outPath9 v009
  putStrLn $ "Wrote generated migration to: " ++ outPath9

  -- Persist V010 migration
  let outPath10 = outDir </> "V010__rbac_name_owner_index.generated.sql"
  writeFile outPath10 v010
  putStrLn $ "Wrote generated migration to: " ++ outPath10

  -- Persist V011 migration
  let outPath11 = outDir </> "V011__rbac_last_seen.generated.sql"
  writeFile outPath11 v011
  putStrLn $ "Wrote generated migration to: " ++ outPath11

  -- Persist V012 migration
  let outPath12 = outDir </> "V012__rbac_last_seen_indexes.generated.sql"
  writeFile outPath12 v012
  putStrLn $ "Wrote generated migration to: " ++ outPath12

  -- Persist V013 migration
  let outPath13 = outDir </> "V013__rbac_is_revoked.generated.sql"
  writeFile outPath13 v013
  putStrLn $ "Wrote generated migration to: " ++ outPath13

  -- Persist V014 migration
  let outPath14 = outDir </> "V014__rbac_policy_class.generated.sql"
  writeFile outPath14 v014
  putStrLn $ "Wrote generated migration to: " ++ outPath14

  -- Persist V015 migration
  let outPath15 = outDir </> "V015__rbac_data_version.generated.sql"
  writeFile outPath15 v015
  putStrLn $ "Wrote generated migration to: " ++ outPath15

  -- Persist V016 migration
  let outPath16 = outDir </> "V016__rbac_row_version.generated.sql"
  writeFile outPath16 v016
  putStrLn $ "Wrote generated migration to: " ++ outPath16

  -- Persist V017 migration
  let outPath17 = outDir </> "V017__rbac_audit_tag.generated.sql"
  writeFile outPath17 v017
  putStrLn $ "Wrote generated migration to: " ++ outPath17

  -- Persist V018 migration
  let outPath18 = outDir </> "V018__rbac_etag.generated.sql"
  writeFile outPath18 v018
  putStrLn $ "Wrote generated migration to: " ++ outPath18

  -- Persist V019 migration
  let outPath19 = outDir </> "V019__rbac_log_id.generated.sql"
  writeFile outPath19 v019
  putStrLn $ "Wrote generated migration to: " ++ outPath19

  -- Persist V020 migration
  let outPath20 = outDir </> "V020__rbac_views.generated.sql"
  writeFile outPath20 v020
  putStrLn $ "Wrote generated migration to: " ++ outPath20

  -- Persist V021 migration
  let outPath21 = outDir </> "V021__rbac_constraints.generated.sql"
  writeFile outPath21 v021
  putStrLn $ "Wrote generated migration to: " ++ outPath21

  -- Persist V022 migration
  let outPath22 = outDir </> "V022__rbac_views.generated.sql"
  writeFile outPath22 v022
  putStrLn $ "Wrote generated migration to: " ++ outPath22

  -- Persist V023 migration
  let outPath23 = outDir </> "V023__rbac_notes.generated.sql"
  writeFile outPath23 v023
  putStrLn $ "Wrote generated migration to: " ++ outPath23

  -- Persist V024 migration
  let outPath24 = outDir </> "V024__rbac_notes2.generated.sql"
  writeFile outPath24 v024
  putStrLn $ "Wrote generated migration to: " ++ outPath24

  -- Persist V025 migration
  let outPath25 = outDir </> "V025__rbac_updated_at2.generated.sql"
  writeFile outPath25 v025
  putStrLn $ "Wrote generated migration to: " ++ outPath25

  -- Persist V026 migration
  let outPath26 = outDir </> "V026__rbac_views2.generated.sql"
  writeFile outPath26 v026
  putStrLn $ "Wrote generated migration to: " ++ outPath26

  -- Persist V027 migration
  let outPath27 = outDir </> "V027__rbac_constraints2.generated.sql"
  writeFile outPath27 v027
  putStrLn $ "Wrote generated migration to: " ++ outPath27

  -- Persist V028 migration
  let outPath28 = outDir </> "V028__rbac_final_views.generated.sql"
  writeFile outPath28 v028

