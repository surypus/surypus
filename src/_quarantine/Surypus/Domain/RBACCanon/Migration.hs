{-# LANGUAGE OverloadedStrings #-}
module Surypus.Domain.RBACCanon.Migration where

import Surypus.Infra.SqlGen.DSL (DSL  (..), render, multi, createTable, alterTableAddColumn, addConstraint)

-- Generate V001RBAC Canon SQL migration via DSL
generateV001 :: String
generateV001 = render $ multi
  [ createTable "rbac_canon"
      [ ("id", "BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY")
      , ("name", "TEXT NOT NULL UNIQUE")
      , ("created_at", "TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()")
      ]
  , createTable "rbac_canon_roles"
      [ ("canon_id", "BIGINT NOT NULL REFERENCES rbac_canon")
      , ("role", "TEXT NOT NULL")
      ]
  , createTable "rbac_canon_perms"
      [ ("canon_id", "BIGINT NOT NULL REFERENCES rbac_canon")
      , ("permission", "TEXT NOT NULL")
      ]
  ]

-- Additional migration: build indices for fast lookups
generateV002 :: String
generateV002 = render $ multi
  [ DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_name ON rbac_canon (name);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_roles_canon ON rbac_canon_roles (canon_id);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_perms ON rbac_canon_perms (canon_id);"
  ]

-- Additional migration: add timestamp columns to existing tables
generateV003 :: String
generateV003 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("updated_at", "TIMESTAMP WITHOUT TIME ZONE" )
  , alterTableAddColumn "rbac_canon_roles" ("updated_at", "TIMESTAMP WITHOUT TIME ZONE" )
  , alterTableAddColumn "rbac_canon_perms" ("updated_at", "TIMESTAMP WITHOUT TIME ZONE" )
  ]

-- Additional migration: add description columns to support comments
generateV004 :: String
generateV004 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("description", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("description", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("description", "TEXT" )
  ]

-- Additional migration: add active flag to support soft-deletes / visibility
generateV005 :: String
generateV005 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("active", "BOOLEAN DEFAULT TRUE" )
  , alterTableAddColumn "rbac_canon_roles" ("active", "BOOLEAN DEFAULT TRUE" )
  , alterTableAddColumn "rbac_canon_perms" ("active", "BOOLEAN DEFAULT TRUE" )
  ]

-- Additional migration: add security level descriptor
generateV006 :: String
generateV006 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("security_level", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("security_level", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("security_level", "TEXT" )
  ]

-- Additional migration: add owner_id to all RBAC canon tables
generateV007 :: String
generateV007 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("owner_id", "BIGINT" )
  , alterTableAddColumn "rbac_canon_roles" ("owner_id", "BIGINT" )
  , alterTableAddColumn "rbac_canon_perms" ("owner_id", "BIGINT" )
  ]

-- Additional migration: add created_by to support auditing
generateV008 :: String
generateV008 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("created_by", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("created_by", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("created_by", "TEXT" )
  ]

-- Additional migration: add updated_by metadata for auditing
generateV009 :: String
generateV009 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("updated_by", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("updated_by", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("updated_by", "TEXT" )
  ]

-- Additional migration: add composite index to improve queries combining owner and name
generateV010 :: String
generateV010 = render $ multi
  [ DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_name_owner ON rbac_canon (name, owner_id);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_roles_name_owner ON rbac_canon_roles (canon_id, name, owner_id);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_perms_name_owner ON rbac_canon_perms (canon_id, name, owner_id);"
  ]

-- Additional migration: last_seen/audit fields
generateV011 :: String
generateV011 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("last_seen", "TIMESTAMP WITHOUT TIME ZONE" )
  , alterTableAddColumn "rbac_canon_roles" ("last_seen", "TIMESTAMP WITHOUT TIME ZONE" )
  , alterTableAddColumn "rbac_canon_perms" ("last_seen", "TIMESTAMP WITHOUT TIME ZONE" )
  ]

generateV012 :: String
generateV012 = render $ multi
  [ DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_last_seen ON rbac_canon (last_seen);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_roles_last_seen ON rbac_canon_roles (canon_id, last_seen);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_perms_last_seen ON rbac_canon_perms (canon_id, last_seen);"
  ]
-- Note: generated V008 is defined above; this duplicate block was removed to avoid redeclaration

-- Additional migration: add is_revoked column (V013)
generateV013 :: String
generateV013 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("is_revoked", "BOOLEAN DEFAULT FALSE" )
  , alterTableAddColumn "rbac_canon_roles" ("is_revoked", "BOOLEAN DEFAULT FALSE" )
  , alterTableAddColumn "rbac_canon_perms" ("is_revoked", "BOOLEAN DEFAULT FALSE" )
  ]

-- Migration: add policy_class (V014)
generateV014 :: String
generateV014 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("policy_class", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("policy_class", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("policy_class", "TEXT" )
  ]

-- Migration: add data_version (V015)
generateV015 :: String
generateV015 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("data_version", "INT" )
  , alterTableAddColumn "rbac_canon_roles" ("data_version", "INT" )
  , alterTableAddColumn "rbac_canon_perms" ("data_version", "INT" )
  ]

-- Additional migration: add row_version (for optimistic locking or ordering)
generateV016 :: String
generateV016 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("row_version", "INT NOT NULL DEFAULT 1" )
  , alterTableAddColumn "rbac_canon_roles" ("row_version", "INT NOT NULL DEFAULT 1" )
  , alterTableAddColumn "rbac_canon_perms" ("row_version", "INT NOT NULL DEFAULT 1" )
  ]

-- Additional migration: audit tagging field (generic auditing label)
generateV017 :: String
generateV017 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("audit_tag", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("audit_tag", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("audit_tag", "TEXT" )
  ]

-- Additional migration: add etag/audit tracking token
generateV018 :: String
generateV018 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("etag", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("etag", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("etag", "TEXT" )
  ]

-- Additional migration: add log_id columns (V019)
generateV019 :: String
generateV019 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("log_id", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("log_id", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("log_id", "TEXT" )
  ]

-- Migration: create simple summary views (V020)
generateV020 :: String
generateV020 = render $ multi
  [ DSL "CREATE VIEW v_rbac_canon_view_log AS SELECT id, name, log_id, created_at FROM rbac_canon;"
  , DSL "CREATE VIEW v_rbac_canon_roles_view_log AS SELECT canon_id, role, log_id FROM rbac_canon_roles;"
  , DSL "CREATE VIEW v_rbac_canon_perms_view_log AS SELECT canon_id, permission, log_id FROM rbac_canon_perms;"
  ]

-- V021: add unique constraints across tables (name/owner_id etc.)
generateV021 :: String
generateV021 = render $ multi
  [ addConstraint "rbac_canon" "uq_name_owner" "UNIQUE (name, owner_id)"
  , addConstraint "rbac_canon_roles" "uq_roles_owner" "UNIQUE (canon_id, role, owner_id)"
  , addConstraint "rbac_canon_perms" "uq_perms_owner" "UNIQUE (canon_id, permission, owner_id)"
  ]

-- V022: views for summarized permission data (simple summaries)
generateV022 :: String
generateV022 = render $ multi
  [ DSL "CREATE VIEW v_rbac_canon_summary AS SELECT c.id AS canon_id, c.name, c.owner_id FROM rbac_canon c;"
  , DSL "CREATE VIEW v_rbac_canon_roles_summary AS SELECT cr.canon_id, cr.role, cr.owner_id FROM rbac_canon_roles cr;"
  , DSL "CREATE VIEW v_rbac_canon_perms_summary AS SELECT cp.canon_id, cp.permission, cp.owner_id FROM rbac_canon_perms cp;"
  ]

-- V023: add notes columns to all RBAC canon tables
generateV023 :: String
generateV023 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("notes", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("notes", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("notes", "TEXT" )
  ]

-- V024: add secondary notes column to diversify auditing metadata
generateV024 :: String
generateV024 = render $ multi
  [ alterTableAddColumn "rbac_canon" ("notes2", "TEXT" )
  , alterTableAddColumn "rbac_canon_roles" ("notes2", "TEXT" )
  , alterTableAddColumn "rbac_canon_perms" ("notes2", "TEXT" )
  ]

 -- V025: index optimizations on updated_at fields
generateV025 :: String
generateV025 = render $ multi
  [ DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_updated_at ON rbac_canon (updated_at);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_roles_updated_at ON rbac_canon_roles (updated_at);"
  , DSL "CREATE INDEX IF NOT EXISTS idx_rbac_canon_perms_updated_at ON rbac_canon_perms (updated_at);"
  ]

-- V026: additional views on log fields
generateV026 :: String
generateV026 = render $ multi
  [ DSL "CREATE VIEW v_rbac_canon_log_summary2 AS SELECT log_id FROM rbac_canon;"
  , DSL "CREATE VIEW v_rbac_canon_roles_log_summary2 AS SELECT log_id FROM rbac_canon_roles;"
  , DSL "CREATE VIEW v_rbac_canon_perms_log_summary2 AS SELECT log_id FROM rbac_canon_perms;"
  ]

-- V027: additional check constraints
generateV027 :: String
generateV027 = render $ multi
  [ DSL "ALTER TABLE rbac_canon ADD CONSTRAINT ck_rbac_canon_name CHECK (char_length(name) > 0);"
  , DSL "ALTER TABLE rbac_canon_roles ADD CONSTRAINT ck_rbac_roles_name CHECK (char_length(role) > 0);"
  , DSL "ALTER TABLE rbac_canon_perms ADD CONSTRAINT ck_rbac_perms_name CHECK (char_length(permission) > 0);"
  ]

-- V028: additional final views
generateV028 :: String
generateV028 = render $ multi
  [ DSL "CREATE VIEW v_rbac_canon_full_summary2 AS SELECT id, name, owner_id, log_id FROM rbac_canon;"
  , DSL "CREATE VIEW v_rbac_canon_roles_full_summary2 AS SELECT canon_id, role, log_id FROM rbac_canon_roles;"
  , DSL "CREATE VIEW v_rbac_canon_perms_full_summary2 AS SELECT canon_id, permission, log_id FROM rbac_canon_perms;"
  ]
