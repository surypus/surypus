{-# LANGUAGE DuplicateRecordFields #-}
-- | HR module - Human Resources
module HR
  ( module HR.Contact,
    module HR.Person,
    module HR.Relation,
    module HR.Operations,
    module HR.Employee,
    module HR.Position,
    module HR.Types,
    PersonEx,
    PersonType2  (..),
    module HR.Salary,
  )
where

import HR.Contact
import HR.Person
import HR.Relation
import HR.Operations
import HR.Employee
import HR.Position
import HR.Types
import HR.PersonEx
import HR.Salary