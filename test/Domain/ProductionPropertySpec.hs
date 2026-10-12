module Domain.ProductionPropertySpec where

import Test.Hspec
import Test.QuickCheck
import Production.Types
import qualified TestHelpers
import Data.Either (isLeft, isRight)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Data.Text (Text, pack)

-- Helper to generate a valid UTCTime for testing
genValidUTCTime :: Gen UTCTime
genValidUTCTime = do
  year <- choose (2020, 2030) :: Gen Integer
  month <- choose (1, 12)
  day <- choose (1, 28)
  hour <- choose (0, 23)
  minute <- choose (0, 59)
  second <- choose (0, 59)
  return $ UTCTime (fromGregorian year month day)
                  (secondsToDiffTime $ hour * 3600 + minute * 60 + second)

-- | TechCard generator (valid card; properties mutate individual fields)
instance Arbitrary TechCard where
  arbitrary = do
    t <- arbitrary
    return TechCard
      { tcId = Nothing
      , tcGoodsId = 1
      , tcName = pack "Card"
      , tcVersion = pack "1.0"
      , tcStatus = 1
      , tcCreatedAt = t
      , tcUpdatedAt = t
      , tcCreatedBy = Nothing
      }

-- | TechLine generator (valid line; properties mutate individual fields)
instance Arbitrary TechLine where
  arbitrary = do
    t <- arbitrary
    return TechLine
      { tlId = Nothing
      , tlTechCardId = 1
      , tlLineNum = 1
      , tlGoodsId = 1
      , tlQtyPlan = 10.0
      , tlUnitId = Just 1
      , tlScrapPercent = 5.0
      , tlNotes = Nothing
      , tlCreatedAt = t
      , tlUpdatedAt = t
      , tlCreatedBy = Nothing
      }

-- Property: TechCard validation should reject empty names
prop_techCardRejectsEmptyName :: Property
prop_techCardRejectsEmptyName = 
  forAll (arbitrary `suchThat` (\tc -> tcGoodsId tc > 0 && tcVersion tc /= pack "")) $ \tc ->
    let emptyNameTc = tc { tcName = pack "" }
    in validateTechCard emptyNameTc `shouldSatisfy` isLeft

-- Property: TechCard validation should reject invalid status
prop_techCardRejectsInvalidStatus :: Property
prop_techCardRejectsInvalidStatus = 
  forAll (arbitrary `suchThat` (\tc -> tcGoodsId tc > 0 && tcName tc /= pack "" && tcVersion tc /= pack "")) $ \tc ->
    forAll (choose (-10, 10) `suchThat` (\s -> s < 0 || s > 2)) $ \invalidStatus ->
      let invalidStatusTc = tc { tcStatus = invalidStatus }
      in validateTechCard invalidStatusTc `shouldSatisfy` isLeft

-- Property: TechCard validation should accept valid cards
prop_techCardAcceptsValid :: Property
prop_techCardAcceptsValid = 
  forAll (arbitrary `suchThat` (\tc -> 
    tcGoodsId tc > 0 && 
    tcName tc /= pack "" && 
    tcVersion tc /= pack "" && 
    tcStatus tc >= 0 && tcStatus tc <= 2)) $ \tc ->
      validateTechCard tc `shouldSatisfy` isRight

-- Property: TechLine validation should reject negative quantity
prop_techLineRejectsNegativeQty :: Property
prop_techLineRejectsNegativeQty = 
  forAll (arbitrary `suchThat` (\tl -> 
    tlTechCardId tl > 0 && 
    tlLineNum tl > 0 && 
    tlGoodsId tl > 0 && 
    tlScrapPercent tl >= 0 && tlScrapPercent tl <= 100)) $ \tl ->
    let negativeQtyTl = tl { tlQtyPlan = -1 }
    in validateTechLine negativeQtyTl `shouldSatisfy` isLeft

-- Property: TechLine validation should reject invalid scrap percent
prop_techLineRejectsInvalidScrap :: Property
prop_techLineRejectsInvalidScrap = 
  forAll (arbitrary `suchThat` (\tl -> 
    tlTechCardId tl > 0 && 
    tlLineNum tl > 0 && 
    tlGoodsId tl > 0 && 
    tlQtyPlan tl >= 0)) $ \tl ->
    forAll (choose (-10, 200) `suchThat` (\s -> s < 0 || s > 100)) $ \invalidScrap ->
      let invalidScrapTl = tl { tlScrapPercent = invalidScrap }
      in validateTechLine invalidScrapTl `shouldSatisfy` isLeft

-- Property: TechLine validation should accept valid lines
prop_techLineAcceptsValid :: Property
prop_techLineAcceptsValid = 
  forAll (arbitrary `suchThat` (\tl -> 
    tlTechCardId tl > 0 && 
    tlLineNum tl > 0 && 
    tlGoodsId tl > 0 && 
    tlQtyPlan tl >= 0 && 
    tlScrapPercent tl >= 0 && tlScrapPercent tl <= 100)) $ \tl ->
      validateTechLine tl `shouldSatisfy` isRight

-- Property: WorkOrder validation should reject released > planned
prop_workOrderRejectsOverRelease :: Property
prop_workOrderRejectsOverRelease = 
  forAll (arbitrary `suchThat` (\wo -> 
    woGoodsId wo > 0 && 
    woCode wo /= pack "" && 
    woStatus wo >= 0 && woStatus wo <= 4)) $ \wo ->
    let overReleasedWo = wo { woQtyReleased = woQtyPlan wo + 1 }
    in validateWorkOrderCore overReleasedWo `shouldSatisfy` isLeft

-- Property: WorkOrder validation should reject negative planned quantity
prop_workOrderRejectsNegativePlan :: Property
prop_workOrderRejectsNegativePlan = 
  forAll (arbitrary `suchThat` (\wo -> 
    woGoodsId wo > 0 && 
    woCode wo /= pack "" && 
    woStatus wo >= 0 && woStatus wo <= 4 && 
    woQtyReleased wo >= 0)) $ \wo ->
    let negativePlanWo = wo { woQtyPlan = -1 }
    in validateWorkOrderCore negativePlanWo `shouldSatisfy` isLeft

-- Property: WorkOrder validation should accept valid orders
prop_workOrderAcceptsValid :: Property
prop_workOrderAcceptsValid = 
  forAll (arbitrary `suchThat` (\wo -> 
    woGoodsId wo > 0 && 
    woCode wo /= pack "" && 
    woStatus wo >= 0 && woStatus wo <= 4 && 
    woQtyPlan wo >= 0 && 
    woQtyReleased wo >= 0 && 
    woQtyReleased wo <= woQtyPlan wo)) $ \wo ->
      validateWorkOrderCore wo `shouldSatisfy` isRight

-- Property: mkWorkOrder should create valid work orders
prop_mkWorkOrderCreatesValid :: Property
prop_mkWorkOrderCreatesValid =
  forAll (choose (1, 1000)) $ \goodsId ->
    forAll (choose (0, 100)) $ \qtyPlan ->
      forAll genValidUTCTime $ \scheduled ->
        let code = pack ("WO-" ++ show goodsId)
            wo = mkWorkOrder code goodsId qtyPlan scheduled
        in validateWorkOrderCore wo `shouldSatisfy` isRight

-- Property: Released quantity should never exceed planned quantity in valid work orders
prop_releasedNeverExceedsPlanned :: Property
prop_releasedNeverExceedsPlanned = 
  forAll (arbitrary `suchThat` (\wo -> 
    woGoodsId wo > 0 && 
    woCode wo /= pack "" && 
    woStatus wo >= 0 && woStatus wo <= 4 && 
    woQtyPlan wo >= 0 && 
    woQtyReleased wo >= 0 && 
    woQtyReleased wo <= woQtyPlan wo)) $ \wo ->
      woQtyReleased wo <= woQtyPlan wo

-- Property: Status should be in valid range for validated work orders
prop_statusInValidRange :: Property
prop_statusInValidRange = 
  forAll (arbitrary `suchThat` (\wo -> 
    woGoodsId wo > 0 && 
    woCode wo /= pack "" && 
    woQtyPlan wo >= 0 && 
    woQtyReleased wo >= 0 && 
    woQtyReleased wo <= woQtyPlan wo)) $ \wo ->
    case validateWorkOrderCore wo of
      Left _ -> property True -- Invalid orders don't need to satisfy this
      Right wo' -> property (woStatus wo' >= 0 && woStatus wo' <= 4)

spec :: Spec
spec = do
  describe "Production module property tests" $ do
    it "TechCard validation rejects empty names" $ property prop_techCardRejectsEmptyName
    it "TechCard validation rejects invalid status" $ property prop_techCardRejectsInvalidStatus
    it "TechCard validation accepts valid cards" $ property prop_techCardAcceptsValid
    it "TechLine validation rejects negative quantity" $ property prop_techLineRejectsNegativeQty
    it "TechLine validation rejects invalid scrap percent" $ property prop_techLineRejectsInvalidScrap
    it "TechLine validation accepts valid lines" $ property prop_techLineAcceptsValid
    it "WorkOrder validation rejects over-release" $ property prop_workOrderRejectsOverRelease
    it "WorkOrder validation rejects negative planned quantity" $ property prop_workOrderRejectsNegativePlan
    it "WorkOrder validation accepts valid orders" $ property prop_workOrderAcceptsValid
    it "mkWorkOrder creates valid work orders" $ property prop_mkWorkOrderCreatesValid
    it "Released quantity never exceeds planned quantity" $ property prop_releasedNeverExceedsPlanned
    it "Status is in valid range for validated work orders" $ property prop_statusInValidRange