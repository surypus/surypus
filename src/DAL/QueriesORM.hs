{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | DAL QueriesORM - raw SQL queries for Surypus
module DAL.QueriesORM
  ( personKey
  , goodsKey
  , billKey
  , locationKey
  , lotKey
  , tenantKey
  , taxKey
  , currencyKey
  , billLineFromEntity
  , employeeToDummyUser
  , documentTypeFromEntity
  , orderFromEntity
  , goodsPriceFromEntity
  , currencyFromEntity
  , keyToInt
  , ilike
  , module DAL.Types
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Database.Persist.Sql (Entity(..), fromSqlKey)
import qualified Data.Text as T
import Database.Persist.Sql (toSqlKey, rawSql, Single(..), PersistValue(..), Key, Entity(..), fromSqlKey)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Schema hiding (Entity)
import DAL.Types hiding (PersonEntity, BillEntity, TaxEntity)
import DAL.Conversion

-- | Key helpers
personKey :: Int64 -> Int64
personKey = id

goodsKey :: Int64 -> Int64
goodsKey = id

billKey :: Int64 -> Int64
billKey = id

locationKey :: Int64 -> Int64
locationKey = id

lotKey :: Int64 -> Int64
lotKey = id

tenantKey :: Int64 -> Int64
tenantKey = id

taxKey :: Int64 -> Int64
taxKey = id

currencyKey :: Int64 -> Int64
currencyKey = id

-- | Convert key to Int64
keyToInt :: Int64 -> Int64
keyToInt = id

-- | ILIKE helper for raw SQL
ilike :: Text -> Text -> Text
ilike field val = field <> " ILIKE " <> val

-- | Additional conversion functions needed
billLineFromEntity :: Entity BillLineEntity -> BillLine
billLineFromEntity (Entity lid e) = BillLine
  { lineId = fromIntegral (fromSqlKey lid)
  , lineBillId = billLineEntityBillId e
  , lineGoodId = billLineEntityGoodsId e
  , lineQtty = billLineEntityQtty e
  , linePrice = billLineEntityPrice e
  , lineDiscount = billLineEntityDiscountAmount e
  , lineAmount = billLineEntityAmount e
  }

employeeToDummyUser :: EmployeeEntity -> User
employeeToDummyUser e = User
  { userId = 0
  , userName = employeeEntityFirstName e <> maybe "" (" " <>) (employeeEntityLastName e)
  , userPassword = Nothing
  , userEmail = Nothing
  , userPersonId = Nothing
  , userStatus = "active"
  , userTenantId = 0
  }

documentTypeFromEntity :: Entity DocumentTypeEntity -> DocumentRegisterType
documentTypeFromEntity (Entity tid e) = DocumentRegisterType
  { drtId = fromIntegral (fromSqlKey tid)
  , drtCode = documentTypeEntityCode e
  , drtName = documentTypeEntityName e
  , drtDescription = documentTypeEntityDescription e
  }

orderFromEntity :: Entity OrderHeadEntity -> Order
orderFromEntity (Entity oid e) = Order
  { orderId = fromIntegral (fromSqlKey oid)
  , orderCode = orderHeadEntityCode e
  , orderName = orderHeadEntityName e
  , orderDate = orderHeadEntityDocDate e
  , orderPersonId = orderHeadEntityPersonId e
  , orderLocationId = orderHeadEntityLocationId e
  , orderType = orderHeadEntityDocType e
  , orderTotal = orderHeadEntityTotal e
  , orderDiscount = orderHeadEntityDiscountAmount e
  , orderTax = orderHeadEntityTaxAmount e
  }

goodsPriceFromEntity :: Entity GoodsPriceEntity -> GoodsPrice
goodsPriceFromEntity (Entity gid e) = GoodsPrice
  { goodsPriceId = fromIntegral (fromSqlKey gid)
  , goodsPriceGoodsId = goodsPriceEntityGoodsId e
  , goodsPriceType = goodsPriceEntityPriceType e
  , goodsPricePrice = goodsPriceEntityPrice e
  , goodsPriceMinPrice = goodsPriceEntityMinPrice e
  , goodsPriceStartDate = goodsPriceEntityStartDate e
  , goodsPriceEndDate = goodsPriceEntityEndDate e
  }

currencyFromEntity :: Entity CurrencyEntity -> Currency
currencyFromEntity (Entity cid e) = Currency
  { currencyId = fromIntegral (fromSqlKey cid)
  , currencyCode = currencyEntityCode e
  , currencyName = currencyEntityName e
  }
