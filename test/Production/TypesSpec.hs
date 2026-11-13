{-# LANGUAGE OverloadedStrings #-}

-- | Property-based tests for 'Production.Types' — the pure production-domain
-- validators (record-constructor / guard layer, no DB, no IO).
--
-- Pins the documented semantics of the three guards exported by
-- 'Production.Types':
--   * 'validateTechCard' rejects an empty name or version, a non-positive
--     goods id and a tech-card status outside 0 (draft) .. 2 (archived);
--   * 'validateTechLine' rejects a non-positive card / line / goods id, a
--     negative planned quantity, a negative unit id and a scrap percent
--     outside 0 .. 100;
--   * 'validateWorkOrderCore' rejects an empty code, a non-positive goods id,
--     a negative planned or released quantity, released > planned and a
--     status outside 0 .. 4.
--
-- These functions are total guards; the properties below assert the contract
-- on the accepting side (arbitrary *valid* inputs must yield 'Right') and the
-- unit tests pin each rejecting branch ('Left' with the exact message).
module Production.TypesSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

import Data.Int (Int64)
import Data.Text (Text, pack)
import Data.Time (UTCTime (..), Day, fromGregorian)
import Production.Types

-- | A fixed reference 'UTCTime' used by the deterministic unit tests so that
-- every 'Left'/'Right' expectation is reproducible.
t0 :: UTCTime
t0 = UTCTime (fromGregorian 2026 6 1) 0

-- | Arbitrary but *valid* work orders (all 'validateWorkOrderCore' branches
-- satisfied). The released quantity never exceeds planned and status stays
-- in 0 .. 4 so the property is not vacuous.
genValidWorkOrder :: Gen WorkOrder
genValidWorkOrder = do
  code <- listOf1 (elements (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']))
  goodsId <- choose (1, 1000)
  qtyPlan <- choose (0, 10000)
  qtyReleased <- choose (0, qtyPlan)
  status <- choose (0, 4)
  pure $ wo code goodsId qtyPlan qtyReleased status

-- | Arbitrary but *valid* tech cards (name/version non-empty, goodsId > 0,
-- status in 0 .. 2).
genValidTechCard :: Gen TechCard
genValidTechCard = do
  goodsId <- choose (1, 1000)
  status <- choose (0, 2)
  name <- pack <$> listOf1 (elements (['a' .. 'z'] ++ ['A' .. 'Z']))
  version <- pack <$> listOf1 (elements ['0' .. '9'])
  pure $ tc goodsId status name version

-- | Arbitrary but *valid* tech lines (card id > 0, line number > 0, goods id
-- > 0, quantity >= 0, scrap in 0 .. 100).
genValidTechLine :: Gen TechLine
genValidTechLine = do
  cardId <- choose (1, 1000)
  lineNum <- choose (1, 50)
  goodsId <- choose (1, 1000)
  qtyPlan <- choose (0, 10000)
  scrap <- choose (0, 100)
  pure $ tl cardId lineNum goodsId qtyPlan Nothing scrap

-- | 'WorkOrder' with the fixed/default fields supplied; the five fields that
-- must vary are taken from the arguments. 'code' is a plain 'String' to keep
-- the generators concise; the record field is a 'Text'.
wo ::
  String -> Int64 -> Double -> Double -> Int -> WorkOrder
wo code goodsId qtyPlan qtyReleased status =
  WorkOrder
    { woId = Nothing
    , woCode = pack code
    , woGoodsId = goodsId
    , woTechCardId = Nothing
    , woQtyPlan = qtyPlan
    , woQtyReleased = qtyReleased
    , woStatus = status
    , woStartDate = Nothing
    , woEndDate = Nothing
    , woProcessorId = Nothing
    , woNotes = Nothing
    , woCreatedAt = t0
    , woUpdatedAt = t0
    , woCreatedBy = Nothing
    }

-- | 'TechCard' with defaults.
tc ::
  Int64 -> Int -> Text -> Text -> TechCard
tc goodsId status name version =
  TechCard
    { tcId = Nothing
    , tcGoodsId = goodsId
    , tcName = name
    , tcVersion = version
    , tcStatus = status
    , tcCreatedAt = t0
    , tcUpdatedAt = t0
    , tcCreatedBy = Nothing
    }

-- | 'TechLine' with defaults.
tl ::
  Int64 -> Int -> Int64 -> Double -> Maybe Int64 -> Double -> TechLine
tl techCardId lineNum goodsId qtyPlan unitId scrap =
  TechLine
    { tlId = Nothing
    , tlTechCardId = techCardId
    , tlLineNum = lineNum
    , tlGoodsId = goodsId
    , tlQtyPlan = qtyPlan
    , tlUnitId = unitId
    , tlScrapPercent = scrap
    , tlNotes = Nothing
    , tlCreatedAt = t0
    , tlUpdatedAt = t0
    , tlCreatedBy = Nothing
    }

spec :: Spec
spec = do
  describe "Production.Types.validateWorkOrderCore" $ do
    it "accepts a fully valid work order" $
      validateWorkOrderCore (wo "WO-0001" 42 1000 0 0)
        `shouldBe` Right (wo "WO-0001" 42 1000 0 0)

    it "rejects an empty work order code" $
      validateWorkOrderCore (wo "" 42 1000 0 0)
        `shouldBe` Left "work order code must be set"

    it "rejects a non-positive goods id" $
      validateWorkOrderCore (wo "WO-0002" 0 1000 0 0)
        `shouldBe` Left "goods id must be positive"

    it "rejects a negative planned quantity" $
      validateWorkOrderCore (wo "WO-0003" 42 (-1) 0 0)
        `shouldBe` Left "planned quantity must be non-negative"

    it "rejects a negative released quantity" $
      validateWorkOrderCore (wo "WO-0004" 42 1000 (-1) 0)
        `shouldBe` Left "released quantity cannot be negative"

    it "rejects released quantity exceeding planned" $
      validateWorkOrderCore (wo "WO-0005" 42 1000 1001 0)
        `shouldBe` Left "released cannot exceed planned"

    it "rejects a status below zero" $
      validateWorkOrderCore (wo "WO-0006" 42 1000 0 (-1))
        `shouldBe` Left "status must be between 0 and 4"

    it "rejects a status above four" $
      validateWorkOrderCore (wo "WO-0007" 42 1000 0 5)
        `shouldBe` Left "status must be between 0 and 4"

    prop "accepts every valid work order"
      prop_validateWorkOrderCore_acceptsValid

  describe "Production.Types.validateTechCard" $ do
    it "accepts a valid tech card" $
      validateTechCard (tc 42 1 "Card" "1.0")
        `shouldBe` Right (tc 42 1 "Card" "1.0")

    it "rejects an empty name" $
      validateTechCard (tc 42 1 "" "1.0")
        `shouldBe` Left "tech card name cannot be empty"

    it "rejects an empty version" $
      validateTechCard (tc 42 1 "Card" "")
        `shouldBe` Left "version cannot be empty"

    it "rejects a non-positive goods id" $
      validateTechCard (tc 0 1 "Card" "1.0")
        `shouldBe` Left "goods id must be positive"

    it "rejects a status outside 0..2" $
      validateTechCard (tc 42 3 "Card" "1.0")
        `shouldBe` Left "status must be 0 (draft), 1 (active), or 2 (archived)"

    prop "accepts every valid tech card"
      prop_validateTechCard_acceptsValid

  describe "Production.Types.validateTechLine" $ do
    it "accepts a valid tech line" $
      validateTechLine (tl 42 1 7 100.0 Nothing 5.0)
        `shouldBe` Right (tl 42 1 7 100.0 Nothing 5.0)

    it "rejects a non-positive tech card id" $
      validateTechLine (tl 0 1 7 100.0 Nothing 5.0)
        `shouldBe` Left "tech card id must be positive"

    it "rejects a non-positive line number" $
      validateTechLine (tl 42 0 7 100.0 Nothing 5.0)
        `shouldBe` Left "line number must be positive"

    it "rejects a non-positive goods id" $
      validateTechLine (tl 42 1 0 100.0 Nothing 5.0)
        `shouldBe` Left "goods id must be positive"

    it "rejects a negative planned quantity" $
      validateTechLine (tl 42 1 7 (-1) Nothing 5.0)
        `shouldBe` Left "quantity must be non-negative"

    it "rejects a negative unit id" $
      validateTechLine (tl 42 1 7 100.0 (Just (-1)) 5.0)
        `shouldBe` Left "unit id must be positive when present"

    it "rejects a scrap percent outside 0..100" $
      validateTechLine (tl 42 1 7 100.0 Nothing 101.0)
        `shouldBe` Left "scrap percent must be between 0 and 100"

    prop "accepts every valid tech line"
      prop_validateTechLine_acceptsValid

-- | QuickCheck property: every *valid* work order is accepted.
prop_validateWorkOrderCore_acceptsValid :: Property
prop_validateWorkOrderCore_acceptsValid =
  forAll genValidWorkOrder (\wo ->
    case validateWorkOrderCore wo of
      Left _ -> property False
      Right _ -> property True)

-- | QuickCheck property: every *valid* tech card is accepted.
prop_validateTechCard_acceptsValid :: Property
prop_validateTechCard_acceptsValid =
  forAll genValidTechCard (\tc ->
    case validateTechCard tc of
      Left _ -> property False
      Right _ -> property True)

-- | QuickCheck property: every *valid* tech line is accepted.
prop_validateTechLine_acceptsValid :: Property
prop_validateTechLine_acceptsValid =
  forAll genValidTechLine (\tl ->
    case validateTechLine tl of
      Left _ -> property False
      Right _ -> property True)
