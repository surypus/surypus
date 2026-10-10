{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}
-- | Authorization and permission checking
module Surypus.API.Authorization
  ( Permission(..)
  , Resource(..)
  , requiredPermissionForPathMethod
  , checkPermission
  , hasRole
  , permissionToText
  ) where

import Prelude
import qualified Prelude as P (Read)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.List (isPrefixOf)

-- | Permission for a specific resource
data Permission
  = Read !Resource
  | Write !Resource
  | Create !Resource
  | Delete !Resource
  | Admin !Resource
  | Execute !Resource
  deriving (Show, Eq)

-- | Protected resource
data Resource
  = Persons
  | Goods
  | Bills
  | Orders
  | Reports
  | Settings
  | Users
  | Inventory
  | Production
  | Finance
  | CRM
  | All
  deriving (Show, Eq)

-- | Convert permission to text
permissionToText :: Permission -> Text
permissionToText = \case
  Read r    -> "read:" <> resourceToText r
  Write r   -> "write:" <> resourceToText r
  Create r  -> "create:" <> resourceToText r
  Delete r  -> "delete:" <> resourceToText r
  Admin r   -> "admin:" <> resourceToText r
  Execute r -> "execute:" <> resourceToText r

resourceToText :: Resource -> Text
resourceToText = \case
  Persons    -> "persons"
  Goods      -> "goods"
  Bills      -> "bills"
  Orders     -> "orders"
  Reports    -> "reports"
  Settings   -> "settings"
  Users      -> "users"
  Inventory  -> "inventory"
  Production -> "production"
  Finance    -> "finance"
  CRM        -> "crm"
  All        -> "*"

-- | Parse permission from text
parsePermission :: Text -> Maybe Permission
parsePermission t = case T.breakOn ":" t of
  ("read",    r) -> Read    <$> parseResource (T.drop 1 r)
  ("write",   r) -> Write   <$> parseResource (T.drop 1 r)
  ("create",  r) -> Create  <$> parseResource (T.drop 1 r)
  ("delete",  r) -> Delete  <$> parseResource (T.drop 1 r)
  ("admin",   r) -> Admin   <$> parseResource (T.drop 1 r)
  ("execute", r) -> Execute <$> parseResource (T.drop 1 r)
  _ -> Nothing

parseResource :: Text -> Maybe Resource
parseResource = \case
  "persons"    -> Just Persons
  "goods"      -> Just Goods
  "bills"      -> Just Bills
  "orders"     -> Just Orders
  "reports"    -> Just Reports
  "settings"   -> Just Settings
  "users"      -> Just Users
  "inventory"  -> Just Inventory
  "production" -> Just Production
  "finance"    -> Just Finance
  "crm"        -> Just CRM
  "*"          -> Just All
  _            -> Nothing

-- | Determine required permission for a given path and method
-- Strips /api/v1/ or /api/ prefix before matching resource routes.
requiredPermissionForPathMethod :: Text -> Text -> Maybe Permission
requiredPermissionForPathMethod path method =
  let stripped = case T.stripPrefix "/api/v1/" path of
                  Just s  -> s
                  Nothing -> case T.stripPrefix "/api/" path of
                               Just s  -> s
                               Nothing -> path
  in case stripped of
    s | "persons"    `T.isPrefixOf` s -> Just $ methodToPermission method Persons
      | "goods"      `T.isPrefixOf` s -> Just $ methodToPermission method Goods
      | "bills"      `T.isPrefixOf` s -> Just $ methodToPermission method Bills
      | "orders"     `T.isPrefixOf` s -> Just $ methodToPermission method Orders
      | "reports"    `T.isPrefixOf` s -> Just $ methodToPermission method Reports
      | "settings"   `T.isPrefixOf` s -> Just $ methodToPermission method Settings
      | "users"      `T.isPrefixOf` s -> Just $ methodToPermission method Users
      | "inventory"  `T.isPrefixOf` s -> Just $ methodToPermission method Inventory
      | "production" `T.isPrefixOf` s -> Just $ methodToPermission method Production
      | "finance"    `T.isPrefixOf` s -> Just $ methodToPermission method Finance
      | "crm"        `T.isPrefixOf` s -> Just $ methodToPermission method CRM
      | "admin"      `T.isPrefixOf` s -> Just $ Admin All
      | otherwise -> Nothing

methodToPermission :: Text -> Resource -> Permission
methodToPermission "GET"    = Read
methodToPermission "HEAD"   = Read
methodToPermission "POST"   = Create
methodToPermission "PUT"    = Write
methodToPermission "PATCH"  = Write
methodToPermission "DELETE" = Delete
methodToPermission _        = Execute

-- | Check if user has a specific permission
checkPermission :: [Text] -> Permission -> Bool
checkPermission userRoles perm =
  let permText = permissionToText perm
      requiredRoles = getRequiredRoles perm
  in any (`elem` userRoles) requiredRoles || permText `elem` userRoles

getRequiredRoles :: Permission -> [Text]
getRequiredRoles = \case
  Read _    -> ["reader", "editor", "admin"]
  Write _   -> ["editor", "admin"]
  Create _  -> ["editor", "admin"]
  Delete _  -> ["admin"]
  Admin _   -> ["admin"]
  Execute _ -> ["executor", "admin"]

-- | Check if user has a specific role
hasRole :: [Text] -> Text -> Bool
hasRole roles role = role `elem` roles
