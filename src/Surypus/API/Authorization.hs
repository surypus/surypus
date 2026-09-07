-- | API Authorization helpers
{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.Authorization
  ( requiredPermissionForPathMethod,
    normalizeResourcePath,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Network.HTTP.Types (Method, methodGet, methodPost, methodPut, methodDelete)

-- | Normalize resource path for RBAC matching
normalizeResourcePath :: Text -> Text
normalizeResourcePath path =
  let path' = T.stripStart path
      stripped = fromMaybe path' (T.stripPrefix "/api/v1/" path')
      normalized = T.dropWhileEnd (== '/') stripped
   in normalized
  where
    fromMaybe def Nothing = def
    fromMaybe _ (Just x) = x

-- | Map HTTP method + path to required permission
requiredPermissionForPathMethod :: Method -> Text -> Maybe Text
requiredPermissionForPathMethod method path =
  let normalized = normalizeResourcePath path
      segments = T.splitOn "/" normalized
      isGet = method == methodGet
      isPost = method == methodPost
      isPut = method == methodPut
      isDelete = method == methodDelete
   in case segments of
        ["person"] ->
          Just $ case () of
            _ | isGet -> "person:read"
              | isPost -> "person:write"
              | isPut -> "person:write"
              | isDelete -> "person:delete"
              | otherwise -> "person:read"
        ["persons"] ->
          Just "person:read"
        ["person", _id] ->
          Just $ case () of
            _ | isGet -> "person:read"
              | isPut -> "person:write"
              | isDelete -> "person:delete"
              | otherwise -> "person:read"
        ["person", _id, "search"] ->
          Just "person:read"
        ["goods"] ->
          Just $ case () of
            _ | isGet -> "goods:read"
              | isPost -> "goods:write"
              | otherwise -> "goods:read"
        ["goods", _id] ->
          Just $ case () of
            _ | isGet -> "goods:read"
              | isPut -> "goods:write"
              | isDelete -> "goods:delete"
              | otherwise -> "goods:read"
        ["goods", "search"] ->
          Just "goods:read"
        ["bill"] ->
          Just $ case () of
            _ | isGet -> "bill:read"
              | isPost -> "bill:write"
              | otherwise -> "bill:read"
        ["bill", _id, "status"] ->
          Just "bill:post"
        ["bill", _id] ->
          Just $ case () of
            _ | isGet -> "bill:read"
              | isPut -> "bill:write"
              | isDelete -> "bill:delete"
              | otherwise -> "bill:read"
        ["bills"] ->
          Just $ case () of
            _ | isGet -> "bill:read"
              | isPost -> "bill:write"
              | otherwise -> "bill:read"
        ["bills", _id] ->
          Just $ case () of
            _ | isGet -> "bill:read"
              | isDelete -> "bill:delete"
              | otherwise -> "bill:read"
        ["bills", _id, "status"] ->
          Just "bill:post"
        ["bill-templates"] ->
          Just $ case () of
            _ | isGet -> "bill:read"
              | isPost -> "bill:write"
              | otherwise -> "bill:read"
        ["bill-templates", _id] ->
          Just $ case () of
            _ | isDelete -> "bill:delete"
              | otherwise -> "bill:read"
        ["payment"] ->
          Just $ case () of
            _ | isGet -> "payment:read"
              | isPost -> "payment:write"
              | isPut -> "payment:write"
              | isDelete -> "payment:delete"
              | otherwise -> "payment:read"
        ["payments"] ->
          Just $ case () of
            _ | isGet -> "payment:read"
              | isPost -> "payment:write"
              | otherwise -> "payment:read"
        ["payments", "aging"] ->
          Just "payment:read"
        ["payments", _id] ->
          Just $ case () of
            _ | isGet -> "payment:read"
              | isPut -> "payment:write"
              | isDelete -> "payment:delete"
              | otherwise -> "payment:read"
        ["location"] ->
          Just $ case () of
            _ | isGet -> "location:read"
              | isPost -> "location:write"
              | isPut -> "location:write"
              | isDelete -> "location:delete"
              | otherwise -> "location:read"
        ["locations"] ->
          Just "location:read"
        ["location", _id] ->
          Just $ case () of
            _ | isGet -> "location:read"
              | isPut -> "location:write"
              | isDelete -> "location:delete"
              | otherwise -> "location:read"
        ["stock"] -> Just "stock:read"
        ["stock", "summary"] -> Just "stock:read"
        ["stock", "valuation"] -> Just "stock:read"
        ["stock", "movements"] -> Just $ case () of
          _ | isGet -> "stock:read"
            | isPost -> "stock:write"
            | otherwise -> "stock:read"
        ["stock", "movements", "goods", _gid] -> Just "stock:read"
        ["stock", _gid, _lid] -> Just "stock:read"
        ["stock", "bygoods", _gid] -> Just "stock:read"
        ["goods", "low-stock"] -> Just "stock:read"
        ["accounting"] ->
          Just $ case () of
            _ | isGet -> "accounting:read"
              | isPost -> "accounting:write"
              | otherwise -> "accounting:read"
        ["accounting", "accounts"] ->
          Just $ case () of
            _ | isGet -> "accounting:read"
              | isPost -> "accounting:write"
              | otherwise -> "accounting:read"
        ["accounting", "accounts", _id] ->
          Just $ case () of
            _ | isGet -> "accounting:read"
              | isPut -> "accounting:write"
              | isDelete -> "accounting:write"
              | otherwise -> "accounting:read"
        ["accounting", "entries"] ->
          Just $ case () of
            _ | isGet -> "accounting:read"
              | isPost -> "accounting:write"
              | otherwise -> "accounting:read"
        ["accounting", "entries", _id] ->
          Just $ case () of
            _ | isGet -> "accounting:read"
              | isPut -> "accounting:write"
              | isDelete -> "accounting:write"
              | otherwise -> "accounting:read"
        ["accounting", "balance-history"] -> Just "accounting:read"
        ["payroll"] -> Just "payroll:read"
        ["payroll", "employees"] -> Just "payroll:read"
        ["payroll", "employees", _id] -> Just "payroll:read"
        ["payroll", "salaries"] -> Just "payroll:read"
        ["payroll", "salaries", _id] -> Just "payroll:read"
        ["reports"] -> Just "reports:read"
        ["reports", "templates"] -> Just "reports:read"
        ["reports", "jrxml", _name] -> Just "reports:read"
        ["users"] -> Just "users:read"
        ["roles"] -> Just "users:read"
        ["grants"] -> Just "users:read"
        ["audit"] -> Just "admin:access"
        ["dashboard"] -> Just "reports:read"
        _ -> Nothing