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
import qualified Data.Text as T
import Database.Persist.Sql (toSqlKey, rawSql, Single(..), PersistValue(..))
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Schema
import DAL.Types
import DAL.Conversion

-- | Key helpers
personKey :: Int64 -> Key PersonEntity
personKey n = toSqlKey n

goodsKey :: Int64 -> Key GoodsEntity
goodsKey n = toSqlKey n

billKey :: Int64 -> Key BillEntity
billKey n = toSqlKey n

locationKey :: Int64 -> Key LocationEntity
locationKey n = toSqlKey n

lotKey :: Int64 -> Key LotEntity
lotKey n = toSqlKey n

tenantKey :: Int64 -> Key TenantEntity
tenantKey n = toSqlKey n

taxKey :: Int64 -> Key TaxEntity
taxKey n = toSqlKey n

currencyKey :: Int64 -> Key CurrencyEntity
currencyKey n = toSqlKey n

-- | Convert key to Int64
keyToInt :: Key a -> Int64
keyToInt = fromIntegral . unKey

-- | ILIKE helper for raw SQL
ilike :: Text -> Text -> Text
ilike field val = field <> " ILIKE " <> val

-- | Additional conversion functions needed
billLineFromEntity :: Entity BillLineEntity -> BillLine
billLineFromEntity (Entity lid e) = BillLine
  { lineId = keyToInt lid
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
  { drtId = keyToInt tid
  , drtCode = documentTypeEntityCode e
  , drtName = documentTypeEntityName e
  , drtDescription = documentTypeEntityDescription e
  }

orderFromEntity :: Entity OrderHeadEntity -> Order
orderFromEntity (Entity oid e) = Order
  { orderId = keyToInt oid
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
  { goodsPriceId = keyToInt gid
  , goodsPriceGoodsId = goodsPriceEntityGoodsId e
  , goodsPriceType = goodsPriceEntityPriceType e
  , goodsPricePrice = goodsPriceEntityPrice e
  , goodsPriceMinPrice = goodsPriceEntityMinPrice e
  , goodsPriceStartDate = goodsPriceEntityStartDate e
  , goodsPriceEndDate = goodsPriceEntityEndDate e
  }

currencyFromEntity :: Entity CurrencyEntity -> Currency
currencyFromEntity (Entity cid e) = Currency
  { currencyId = keyToInt cid
  , currencyCode = currencyEntityCode e
  , currencyName = currencyEntityName e
  }
