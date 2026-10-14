-- ============================================================================
-- ADDITIONAL UNIT TESTS
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module AdditionalTests where

import Test.Hspec
import Data.Text (Text)
import Data.Time.Calendar (Day)
import qualified Data.Text as T
import Surypus.Foreign.QML
import Surypus.Reports.Templates
import Surypus.Reports.Conversion.CrystalTypes
import Surypus.Reports.Conversion.CrystalToPdfSlave
import Core.Payroll.Calculation

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = hspec $ do
    describe "Data Validation" $ do
        it "validate INN - valid 10 digits" $ do
            validateInn "7701234567" `shouldBe` True
            
        it "validate INN - valid 12 digits" $ do
            validateInn "770123456789" `shouldBe` True
            
        it "validate INN - invalid too short" $ do
            validateInn "770123456" `shouldBe` False
            
        it "validate INN - invalid with letters" $ do
            validateInn "7701234567a" `shouldBe` False
            
        it "validate KPP - valid" $ do
            validateKpp "770101001" `shouldBe` True
            
        it "validate KPP - invalid" $ do
            validateKpp "77010100" `shouldBe` False
            
    describe "Currency Formatting" $ do
        it "format integer amount" $ do
            formatCurrency 1000 `shouldBe` "1000.00 руб."
            
        it "format decimal amount" $ do
            formatCurrency 1234.56 `shouldBe` "1234.56 руб."
            
    describe "Data Retrieval" $ do
        it "get person by ID" $ do
            let person = getPersonById samplePersons 1
            person `shouldSatisfy` isJust
            
        it "get person by ID - not found" $ do
            let person = getPersonById samplePersons 999
            person `shouldBe` Nothing
            
        it "get goods by ID" $ do
            let goods = getGoodsById sampleGoods 1
            goods `shouldSatisfy` isJust
            
        it "get location by ID" $ do
            let location = getLocationById sampleLocations 1
            location `shouldSatisfy` isJust
            
    describe "Filtering" $ do
        it "filter persons by status" $ do
            let active = filterPersonsByStatus samplePersons StatusActive
            length active `shouldBe` 3
            
        it "filter persons by type" $ do
            let companies = filterPersonsByType samplePersons PersonCompany
            length companies `shouldBe` 2
            
        it "filter goods by type" $ do
            let products = filterGoodsByType sampleGoods GoodsProduct
            length products `shouldBe` 3
            
        it "filter jobs by status" $ do
            let pending = filterJobsByStatus sampleJobs JobPending
            length pending `shouldBe` 2
            
    describe "Calculations" $ do
        it "calculate bill totals" $ do
            let (total, vat, totalWithVat) = calculateBillTotals sampleBills
            total `shouldBe` 75000.0
            vat `shouldBe` 15000.0
            totalWithVat `shouldBe` 90000.0
            
        it "calculate payroll totals" $ do
            let payroll = [Payroll 1 1 "2026-03" 20 160 100000 5000 13000 0 3000 52000 (Just $ read "2026-03-31") StatusCompleted]
            let (accrued, tax, social, net) = calculatePayrollTotals payroll
            accrued `shouldBe` 100000.0
            tax `shouldBe` 13000.0
            social `shouldBe` 3000.0
            net `shouldBe` 52000.0
            
            
    describe "Text Processing" $ do
        it "concatenate texts" $ do
            let result = T.concat ["Hello", " ", "World"]
            result `shouldBe` "Hello World"
            
        it "check empty text" $ do
            T.null "" `shouldBe` True
            T.null "test" `shouldBe` False
            
        it "text length" $ do
            T.length "hello" `shouldBe` 5
            
    describe "Payroll Calculations" $ do
        it "calcIncomeTax low salary" $ do
            calcIncomeTax 100000 `shouldBe` 13000.0
            
        it "calcIncomeTax high salary" $ do
            calcIncomeTax 5000000 `shouldBe` 65000.0 + 450000.0 + 2700000.0 + 900000.0
            
        it "calcSocialTax" $ do
            calcSocialTax 50000 `shouldBe` 15000.0
            
        it "calcNetSalaryFromGross" $ do
            calcNetSalaryFromGross 100000 `shouldBe` 87000.0
            
        it "calcVacationDays" $ do
            let start = read "2026-03-01" :: Day
                end = read "2026-03-15" :: Day
            calcVacationDays start end `shouldBe` 15
            
        it "calcSickLeavePay first 3 days" $ do
            calcSickLeavePay 1000 5 True `shouldBe` 1800.0
            
        it "calcSickLeavePay after 3 days" $ do
            calcSickLeavePay 1000 5 False `shouldBe` 4000.0
            
    describe "Template Loading" $ do
        it "all template types defined" $ do
            length allTemplates `shouldBe` 9
            
        it "template names" $ do
            let names = map (T.unpack . fst) allTemplates
            names `shouldContain` "Счёт-фактура"
            names `shouldContain` "Счёт на оплату"
            
    describe "Crystal Report Types" $ do
        it "create CrystalReport" $ do
            let report = CrystalReport
                    { crName = "Test"
                    , crSections = []
                    , crGroups = []
                    , crParameters = []
                    , crDatabaseFields = []
                    , crFormulaFields = []
                    , crSubreports = []
                    }
            crName report `shouldBe` "Test"
            
        it "create CrystalSection" $ do
            let section = ReportHeaderSection []
            case section of
                ReportHeaderSection _ -> True `shouldBe` True
                _ -> False `shouldBe` True
                
    describe "PDF Slave Conversion" $ do
        it "convert Crystal to PDF Slave" $ do
            let report = CrystalReport
                    { crName = "Invoice"
                    , crSections = [ReportHeaderSection []]
                    , crGroups = []
                    , crParameters = []
                    , crDatabaseFields = []
                    , crFormulaFields = []
                    , crSubreports = []
                    }
            let template = convertCrystalToPdfSlave report
            pmTitle (ptMeta template) `shouldBe` "Invoice"
            
    describe "Date Formatting" $ do
        it "format date" $ do
            let day = read "2026-03-11" :: Day
            formatDate day `shouldBe` "2026-03-11"
            
    describe "Navigation" $ do
        it "default navigation has items" $ do
            length defaultNavigation `shouldBe` 11
            
        it "navigation item fields" $ do
            let nav = head defaultNavigation
            navTitle nav `shouldBe` "Главная"
            navPage nav `shouldBe` "DashboardPage.qml"
            
    describe "Configuration" $ do
        it "default config values" $ do
            cfgApiUrl defaultConfig `shouldBe` "http://localhost:8080/api/v1"
            cfgDbHost defaultConfig `shouldBe` "localhost"
            cfgDbPort defaultConfig `shouldBe` 5432
            
        it "default theme values" $ do
            themePrimary defaultTheme `shouldBe` "#1976D2"
            themeSuccess defaultTheme `shouldBe` "#4CAF50"
            
-- Helper
isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing = False
