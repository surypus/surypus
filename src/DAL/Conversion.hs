{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Conversion where

import Data.Decimal (Decimal)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text, pack)
import DAL.Schema
import DAL.Types as T
import Database.Persist (Entity(..), Key, PersistEntity, keyToValues)
import Database.Persist.PersistValue (PersistValue(..))

keyToInt :: forall record. PersistEntity record => Key record -> Int64
keyToInt k = case keyToValues k of
  [PersistInt64 n] -> n
  _ -> error "keyToInt: expected Int64 key"

personFromEntity :: Entity PersonEntity -> T.Person
personFromEntity (Entity pid e) = T.Person
  { T.personId = keyToInt pid
  , T.personCode = personEntityCode e
  , T.personName = personEntityName e
  , T.personINN = personEntityInn e
  , T.personKPP = personEntityKpp e
  , T.personType = personEntityPersonType e
  , T.personStatus = personEntityStatus e
  }

goodsFromEntity :: Entity GoodsEntity -> T.Goods
goodsFromEntity (Entity pid e) = T.Goods
  { T.goodsId = keyToInt pid
  , T.goodsCode = goodsEntityCode e
  , T.goodsName = goodsEntityName e
  , T.goodsFullName = goodsEntityFullName e
  , T.goodsBarcode = goodsEntityBarcode e
  , T.goodsUnitId = goodsEntityUnitId e
  , T.goodsCategoryId = goodsEntityCategoryId e
  , T.goodsType = goodsEntityGoodsType e
  , T.goodsStatus = goodsEntityGoodsStatus e
  , T.goodsMinStock = goodsEntityMinStock e
  , T.goodsMaxStock = goodsEntityMaxStock e
  , T.goodsWeight = goodsEntityWeight e
  , T.goodsVolume = goodsEntityVolume e
  , T.goodsCreatedAt = goodsEntityCreatedAt e
  , T.goodsUpdatedAt = goodsEntityUpdatedAt e
  }

billFromEntity :: Entity BillEntity -> T.Bill
billFromEntity (Entity pid e) = T.Bill
  { T.billId = keyToInt pid
  , T.billCode = billEntityCode e
  , T.billType = billEntityBillType e
  , T.billStatus = billEntityDocStatus e
  , T.billDate = billEntityDocDate e
  , T.billPersonId = billEntityPersonId e
  , T.billLocationId = billEntityLocationId e
  , T.billTotal = billEntityTotal e
  , T.billDiscount = billEntityDiscountAmount e
  , T.billTaxAmount = billEntityTaxAmount e
  }

userFromEntity :: Entity UserEntity -> T.User
userFromEntity (Entity pid e) = T.User
  { T.userId = keyToInt pid
  , T.userName = userEntityUsername e
  , T.userPassword = Just (userEntityPasswordHash e)
  , T.userEmail = userEntityEmail e
  , T.userPersonId = userEntityPersonId e
  , T.userStatus = userEntityStatus e
  , T.userTenantId = userEntityTenantId e
  }

locationFromEntity :: Entity LocationEntity -> T.Location
locationFromEntity (Entity pid e) = T.Location
  { T.locationId = keyToInt pid
  , T.locationCode = locationEntityCode e
  , T.locationName = locationEntityName e
  , T.locationType = locationEntityLocationType e
  }

lotFromEntity :: Entity LotEntity -> T.Lot
lotFromEntity (Entity pid e) = T.Lot
  { T.lotId = keyToInt pid
  , T.lotGoodsId = lotEntityGoodsId e
  , T.lotLocationId = lotEntityLocationId e
  , T.lotBillId = lotEntityBillId e
  , T.lotDate = lotEntityDt e
  , T.lotExpiry = lotEntityExpDt e
  , T.lotRest = lotEntityRest e
  , T.lotCost = lotEntityCost e
  , T.lotPrice = lotEntityPrice e
  , T.lotSerial = lotEntitySerial e
  , T.lotFlags = lotEntityFlags e
  }

tenantFromEntity :: Entity TenantEntity -> T.Tenant
tenantFromEntity (Entity pid e) = T.Tenant
  { T.tenantId = keyToInt pid
  , T.tenantName = tenantEntityName e
  , T.tenantSlug = tenantEntitySlug e
  , T.tenantSchemaName = tenantEntitySchemaName e
  , T.tenantIsActive = tenantEntityIsActive e
  }

stockFromEntity :: Entity StockEntity -> T.Stock
stockFromEntity (Entity pid e) = T.Stock
  { T.stockId = keyToInt pid
  , T.stockGoodsId = stockEntityGoodsId e
  , T.stockLocationId = stockEntityLocationId e
  , T.stockQtty = stockEntityQtty e
  , T.stockResrvQtty = stockEntityResrvQtty e
  }

paymentFromEntity :: Entity PaymentEntity -> T.Payment
paymentFromEntity (Entity pid e) = T.Payment
  { T.paymentId = keyToInt pid
  , T.paymentPersonId = paymentEntityBillId e
  , T.paymentAmount = paymentEntityAmount e
  , T.paymentDate = paymentEntityDate e
  }

unitFromEntity :: Entity UnitEntity -> T.Unit
unitFromEntity (Entity pid e) = T.Unit
  { T.unitId = keyToInt pid
  , T.unitCode = unitEntityCode e
  , T.unitName = unitEntityName e
  , T.unitSymbol = unitEntitySymbol e
  }

taxFromEntity :: Entity TaxEntity -> T.Tax
taxFromEntity (Entity pid e) = T.Tax
  { T.taxId = keyToInt pid
  , T.taxCode = fromMaybe (pack "") (taxEntityCode e)
  , T.taxName = taxEntityName e
  , T.taxRate = taxEntityRate e
  }

accPlanFromEntity :: Entity AccPlanEntity -> T.AccPlan
accPlanFromEntity (Entity pid e) = T.AccPlan
  { T.accPlanId = keyToInt pid
  , T.accPlanCode = accPlanEntityCode e
  , T.accPlanName = accPlanEntityName e
  , T.accPlanType = accPlanEntityAccType e
  }

accTurnFromEntity :: Entity AccTurnEntity -> T.AccTurn
accTurnFromEntity (Entity pid e) = T.AccTurn
  { T.accTurnId = keyToInt pid
  , T.accTurnDocId = accTurnEntityDocId e
  , T.accTurnAccId = accTurnEntityDbtAccId e
  , T.accTurnCorrId = accTurnEntityCrdAccId e
  , T.accTurnAmount = accTurnEntityAmount e
  , T.accTurnDate = accTurnEntityDate e
  }

employeeFromEntity :: Entity EmployeeEntity -> T.Employee
employeeFromEntity (Entity pid e) = T.Employee
  { T.employeeId = keyToInt pid
  , T.employeeName = employeeEntityName e
  , T.employeeCode = employeeEntityCode e
  , T.employeeTabNum = employeeEntityTabNum e
  , T.employeeHireDate = employeeEntityHireDate e
  , T.employeeStatus = employeeEntityStatus e
  }

salaryFromEntity :: Entity SalaryEntity -> T.Salary
salaryFromEntity (Entity pid e) = T.Salary
  { T.salaryId = keyToInt pid
  , T.salaryEmpId = salaryEntityEmployeeId e
  , T.salaryDate = salaryEntityDate e
  , T.salaryGross = salaryEntityGross e
  , T.salaryNet = salaryEntityNet e
  , T.salaryTax = salaryEntityTaxAmount e
  , T.salaryPension = salaryEntityPension e
  , T.salaryOther = salaryEntityOther e
  }

timesheetFromEntity :: Entity TimesheetEntity -> T.Timesheet
timesheetFromEntity (Entity pid e) = T.Timesheet
  { T.timesheetId = keyToInt pid
  , T.timesheetEmployeeId = timesheetEntityEmployeeId e
  , T.timesheetDate = timesheetEntityDate e
  , T.timesheetHoursWorked = timesheetEntityHoursWorked e
  , T.timesheetNotes = timesheetEntityNotes e
  , T.timesheetCreatedBy = timesheetEntityCreatedBy e
  , T.timesheetCreatedAt = timesheetEntityCreatedAt e
  }

stockMovementFromEntity :: Entity StockMovementEntity -> T.StockMovement
stockMovementFromEntity (Entity pid e) = T.StockMovement
  { T.smId = keyToInt pid
  , T.smGoodsId = stockMovementEntityGoodsId e
  , T.smLocationFromId = stockMovementEntityLocationFromId e
  , T.smLocationToId = stockMovementEntityLocationToId e
  , T.smQtty = stockMovementEntityQtty e
  , T.smMovementType = stockMovementEntityMovementType e
  , T.smBillId = stockMovementEntityBillId e
  , T.smMovementDate = stockMovementEntityMovementDate e
  , T.smUserId = stockMovementEntityUserId e
  , T.smNotes = stockMovementEntityNotes e
  , T.smCreatedAt = stockMovementEntityCreatedAt e
  }

oksmFromEntity :: Entity OksmEntity -> T.OksmRecord
oksmFromEntity (Entity pid e) = T.OksmRecord
  { T.oksmId = keyToInt pid
  , T.oksmCode = oksmEntityCode e
  , T.oksmName = oksmEntityName e
  , T.oksmFullName = oksmEntityFullName e
  , T.oksmAlpha2 = oksmEntityAlpha2 e
  , T.oksmAlpha3 = oksmEntityAlpha3 e
  }

okvFromEntity :: Entity OkvEntity -> T.OkvRecord
okvFromEntity (Entity pid e) = T.OkvRecord
  { T.okvId = keyToInt pid
  , T.okvCode = okvEntityCode e
  , T.okvLetterCode = okvEntityLetterCode e
  , T.okvName = okvEntityName e
  , T.okvCountries = okvEntityCountries e
  }

okeiFromEntity :: Entity OkeiEntity -> T.OkeiRecord
okeiFromEntity (Entity pid e) = T.OkeiRecord
   { T.okeiId = keyToInt pid
   , T.okeiCode = okeiEntityCode e
   , T.okeiName = okeiEntityName e
   , T.okeiNationalSymbol = okeiEntityNationalSymbol e
   , T.okeiInternationalSymbol = okeiEntityInternationalSymbol e
   , T.okeiNationalLetterCode = okeiEntityNationalLetterCode e
   , T.okeiInternationalLetterCode = okeiEntityInternationalLetterCode e
   , T.okeiSection = okeiEntitySection e
   }

okpd2FromEntity :: Entity Okpd2Entity -> T.Okpd2Record
okpd2FromEntity (Entity pid e) = T.Okpd2Record
   { T.okpd2Id = keyToInt pid
   , T.okpd2Code = okpd2EntityCode e
   , T.okpd2Name = okpd2EntityName e
   , T.okpd2ParentCode = okpd2EntityParentCode e
   }

okved2FromEntity :: Entity Okved2Entity -> T.Okved2Record
okved2FromEntity (Entity pid e) = T.Okved2Record
   { T.okved2Id = keyToInt pid
   , T.okved2Code = okved2EntityCode e
   , T.okved2Name = okved2EntityName e
   , T.okved2ParentCode = okved2EntityParentCode e
   }

tnvedFromEntity :: Entity TnvedEntity -> T.TnvedRecord
tnvedFromEntity (Entity pid e) = T.TnvedRecord
   { T.tnvedId = keyToInt pid
   , T.tnvedCode = tnvedEntityCode e
   , T.tnvedName = tnvedEntityName e
   , T.tnvedParentCode = tnvedEntityParentCode e
   , T.tnvedSectionNum = tnvedEntitySectionNum e
   , T.tnvedGroupNum = tnvedEntityGroupNum e
   }

okatoFromEntity :: Entity OkatoEntity -> T.OkatoRecord
okatoFromEntity (Entity pid e) = T.OkatoRecord
   { T.okatoId = keyToInt pid
   , T.okatoCode = okatoEntityCode e
   , T.okatoName = okatoEntityName e
   , T.okatoParentCode = okatoEntityParentCode e
   , T.okatoLevel = okatoEntityLevel e
   }

oktmoFromEntity :: Entity OktmoEntity -> T.OktmoRecord
oktmoFromEntity (Entity pid e) = T.OktmoRecord
   { T.oktmoId = keyToInt pid
   , T.oktmoCode = oktmoEntityCode e
   , T.oktmoName = oktmoEntityName e
   , T.oktmoParentCode = oktmoEntityParentCode e
   }

okofFromEntity :: Entity OkofEntity -> T.OkofRecord
okofFromEntity (Entity pid e) = T.OkofRecord
   { T.okofId = keyToInt pid
   , T.okofCode = okofEntityCode e
   , T.okofName = okofEntityName e
   , T.okofParentCode = okofEntityParentCode e
   }

okpFromEntity :: Entity OkpEntity -> T.OkpRecord
okpFromEntity (Entity pid e) = T.OkpRecord
   { T.okpId = keyToInt pid
   , T.okpCode = okpEntityCode e
   , T.okpName = okpEntityName e
   , T.okpParentCode = okpEntityParentCode e
   }

okdpFromEntity :: Entity OkdpEntity -> T.OkdpRecord
okdpFromEntity (Entity pid e) = T.OkdpRecord
   { T.okdpId = keyToInt pid
   , T.okdpCode = okdpEntityCode e
   , T.okdpName = okdpEntityName e
   , T.okdpParentCode = okdpEntityParentCode e
   }

oksoFromEntity :: Entity OksoEntity -> T.OksoRecord
oksoFromEntity (Entity pid e) = T.OksoRecord
   { T.oksoId = keyToInt pid
   , T.oksoCode = oksoEntityCode e
   , T.oksoName = oksoEntityName e
   }

okunFromEntity :: Entity OkunEntity -> T.OkunRecord
okunFromEntity (Entity pid e) = T.OkunRecord
   { T.okunId = keyToInt pid
   , T.okunCode = okunEntityCode e
   , T.okunName = okunEntityName e
   , T.okunParentCode = okunEntityParentCode e
   }

okudFromEntity :: Entity OkudEntity -> T.OkudRecord
okudFromEntity (Entity pid e) = T.OkudRecord
   { T.okudId = keyToInt pid
   , T.okudCode = okudEntityCode e
   , T.okudName = okudEntityName e
   }

okfsFromEntity :: Entity OkfsEntity -> T.OkfsRecord
okfsFromEntity (Entity pid e) = T.OkfsRecord
   { T.okfsId = keyToInt pid
   , T.okfsCode = okfsEntityCode e
   , T.okfsName = okfsEntityName e
   }

oknpoFromEntity :: Entity OknpoEntity -> T.OknpoRecord
oknpoFromEntity (Entity pid e) = T.OknpoRecord
   { T.oknpoId = keyToInt pid
   , T.oknpoCode = oknpoEntityCode e
   , T.oknpoName = oknpoEntityName e
   }

payrollResultFromEntity :: Entity PayrollResultEntity -> T.PayrollResult
payrollResultFromEntity (Entity pid e) = T.PayrollResult
  { T.prId = keyToInt pid
  , T.prTenantId = payrollResultEntityTenantId e
  , T.prPeriod = payrollResultEntityPeriod e
  , T.prEmployeeId = payrollResultEntityEmployeeId e
  , T.prGross = realToFrac (payrollResultEntityGross e)
  , T.prDeductions = realToFrac (payrollResultEntityDeductions e)
  , T.prNet = realToFrac (payrollResultEntityNet e)
  , T.prIncomeTax = realToFrac (payrollResultEntityIncomeTax e)
  , T.prSocialTax = realToFrac (payrollResultEntitySocialTax e)
  , T.prAdvance = realToFrac (payrollResultEntityAdvance e)
  , T.prBonus = realToFrac (payrollResultEntityBonus e)
  , T.prVacationPay = realToFrac (payrollResultEntityVacationPay e)
  , T.prSickPay = realToFrac (payrollResultEntitySickPay e)
  , T.prTotalToPay = realToFrac (payrollResultEntityTotalToPay e)
  , T.prCurrency = payrollResultEntityCurrency e
  , T.prVersion = payrollResultEntityVersion e
  , T.prCreatedBy = payrollResultEntityCreatedBy e
  , T.prCreatedAt = payrollResultEntityCreatedAt e
  , T.prUpdatedAt = payrollResultEntityUpdatedAt e
  }
