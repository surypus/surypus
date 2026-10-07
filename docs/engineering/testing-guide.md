# Testing Guide

How to write and run tests in Surypus.

## Running Tests

### All Tests

```bash
stack test
```

### Single Test Group

```bash
# Run tests matching a pattern
stack test --match "VAT"

# Run specific spec
stack test --test-arguments "-m \"НДС 20%\""
```

### Single Test File

```bash
stack test --test-arguments "test/Test.hs"
```

### Verbose Output

```bash
stack test --verbose
```

### QuickCheck Properties

```bash
stack test --test-arguments "--quickcheck"
```

---

## Test Structure

```
Surypus/test/
├── Test.hs              -- Main test suite
├── Finance/
│   ├── TaxSpec.hs       -- Tax calculation tests
│   ├── AccountingSpec.hs
│   └── BillSpec.hs
├── Surypus/
│   └── ValidationSpec.hs -- Validation logic tests
├── Integration/
│   ├── APISpec.hs       -- API endpoint tests
│   ├── DatabaseSpec.hs  -- DB tests
│   └── PerformanceSpec.hs
└── Fixtures/
    └── TestFixtures.hs  -- Shared test data
```

---

## Writing Tests

### Unit Tests (Hspec)

```haskell
module Domain.TaxSpec where

import Test.Hspec
import Core.Tax

spec_vat_calculation :: Spec
spec_vat_calculation = describe "calcVAT" $ do
  it "calculates 20% VAT on 1000" $
    calcVAT 1000 (Decimal 20) `shouldBe` Decimal 200

  it "returns 0 for negative amount" $
    calcVAT (Decimal (-100)) (Decimal 20) `shouldBe` Decimal 0
```

### Property-Based Tests (QuickCheck)

```haskell
import Test.QuickCheck

prop_vat_nonnegative :: Property
prop_vat_nonnegative = forAll genAmountAndRate $ \(amount, rate) ->
  calcVAT amount rate >= 0

-- Generate valid inputs
genAmountAndRate :: Gen (Decimal, Decimal)
genAmountAndRate = do
  amount <- Decimal . abs <$> choose (100, 100000000 :: Int64)
  rate <- Decimal . abs <$> choose (0, 100 :: Int64)
  pure (amount, rate)
```

### Integration Tests

```haskell
module Integration.APISpec where

import Test.Hspec
import Network.Wai (Application)
import Network.Wai.Test (sresponseStatus, SResponse)

spec_api_endpoints :: Spec
spec_api_endpoints = describe "API Endpoints" $ do
  it "GET /health returns 200" $ do
    response <- simpleHttp "http://localhost:8080/health"
    responseStatus response `shouldBe` Status 200 "OK"
```

---

## TestFixtures

Shared test data for consistent testing:

```haskell
module Fixtures.TestFixtures where

import Surypus.Types

-- Sample company
testCompany :: Company
testCompany = Company
  { cId = 1
  , cName = "Test Company"
  , cInn = "1234567890"
  }

-- Sample tax rate
testTaxRate20 :: TaxRate
testTaxRate20 = TaxRate
  { trId = 1
  , trName = "НДС 20%"
  , trRate = Decimal 20
  , trFlags = 0
  }

-- Sample goods
testGoods :: Goods
testGoods = Goods
  { gId = 1
  , gName = "Test Product"
  , gCode = "TEST001"
  }
```

---

## CI Pipeline

### GitHub Actions Workflow

```yaml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: haskell/actions/setup@v2
        with:
          ghc-version: '9.12.4'
      - run: stack build
      - run: stack test
      - run: hlint src/
```

### Running Locally

```bash
# Full pipeline
stack build && stack test && hlint src/
```

### Test Coverage

```bash
# Generate coverage report (if HPC enabled)
stack test --coverage
```

---

## Best Practices

1. **Use descriptive test names** - "calculates 20% VAT on 1000" not "test 1"
2. **Test edge cases** - Zero, negative, boundary values
3. **Use property-based testing** - For mathematical operations
4. **Keep fixtures modular** - Separate by domain
5. **Test error paths** - Not just happy path
6. **Name QuickCheck generators** - `genAmountAndRate` not `gen'`