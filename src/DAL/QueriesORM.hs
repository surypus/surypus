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
import qualified Database.Persist.Sql as P (Entity(..), toSqlKey, rawSql, Single(..), PersistValue(..), Key)
import Database.Persist.Postgresql (ConnectionPool)
import DAL.Schema hiding (Entity, BillLineEntity, DocumentTypeEntity, OrderHeadEntity, GoodsPriceEntity, CurrencyEntity)
import qualified DAL.Schema as S (BillLineEntity(..), DocumentTypeEntity(..), OrderHeadEntity(..), GoodsPriceEntity(..), CurrencyEntity(..), EmployeeEntity(..))
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
billLineFromEntity :: Int64 -> S.BillLineEntity -> BillLine
billLineFromEntity lid e = BillLine
  { lineId = lid
  , lineBillId = S.billLineEntityBillId e
  , lineGoodId = S.billLineEntityGoodsId e
  , lineQtty = S.billLineEntityQtty e
  , linePrice = S.billLineEntityPrice e
  , lineDiscount = S.billLineEntityDiscountAmount e
  , lineAmount = S.billLineEntityAmount e
  }

employeeToDummyUser :: S.EmployeeEntity -> User
employeeToDummyUser e = User
  { userId = 0
  , userName = S.employeeEntityFirstName e <> maybe "" (" " <>) (S.employeeEntityLastName e)
  , userPassword = Nothing
  , userEmail = Nothing
  , userPersonId = Nothing
  , userStatus = "active"
  , userTenantId = 0
  }

documentTypeFromEntity :: Int64 -> S.DocumentTypeEntity -> DocumentRegisterType
documentTypeFromEntity tid e = DocumentRegisterType
  { drtId = tid
  , drtCode = S.documentTypeEntityCode e
  , drtName = S.documentTypeEntityName e
  , drtDescription = S.documentTypeEntityDescription e
  }

orderFromEntity :: Int64 -> S.OrderHeadEntity -> Order
orderFromEntity oid e = Order
  { orderId = oid
  , orderCode = S.orderHeadEntityCode e
  , orderName = S.orderHeadEntityName e
  , orderDate = S.orderHeadEntityDocDate e
  , orderPersonId = S.orderHeadEntityPersonId e
  , orderLocationId = S.orderHeadEntityLocationId e
  , orderType = S.orderHeadEntityDocType e
  , orderTotal = S.orderHeadEntityTotal e
  , orderDiscount = S.orderHeadEntityDiscountAmount e
  , orderTax = S.orderHeadEntityTaxAmount e
  }

goodsPriceFromEntity :: Int64 -> S.GoodsPriceEntity -> GoodsPrice
goodsPriceFromEntity gid e = GoodsPrice
  { goodsPriceId = gid
  , goodsPriceGoodsId = S.goodsPriceEntityGoodsId e
  , goodsPriceType = S.goodsPriceEntityPriceType e
  , goodsPricePrice = S.goodsPriceEntityPrice e
  , goodsPriceMinPrice = S.goodsPriceEntityMinPrice e
  , goodsPriceStartDate = S.goodsPriceEntityStartDate e
  , goodsPriceEndDate = S.goodsPriceEntityEndDate e
  }

currencyFromEntity :: Int64 -> S.CurrencyEntity -> Currency
currencyFromEntity cid e = Currency
  { currencyId = cid
  , currencyCode = S.currencyEntityCode e
  , currencyName = S.currencyEntityName e
  }
