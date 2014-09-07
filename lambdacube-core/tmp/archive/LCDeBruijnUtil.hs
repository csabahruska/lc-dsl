module LCDeBruijnUtil where

import Data.Typeable

-- Typed de Bruijn indices
-- -----------------------

-- De Bruijn variable index projecting a specific type from a type
-- environment.  Type environments are nested pairs (..((), t1), t2, ..., tn).
--
data Idx env t where
    ZeroIdx ::              Idx (env, t) t
    SuccIdx :: Idx env t -> Idx (env, s) t


-- Environments
-- ------------

-- Valuation for an environment
--
data Val env where
    Empty :: Val ()
    Push  :: Val env -> t -> Val (env, t)

deriving instance Typeable1 Val


-- Projection of a value from a valuation using a de Bruijn index
--
prj :: Idx env t -> Val env -> t
prj ZeroIdx       (Push _   v) = v
prj (SuccIdx idx) (Push val _) = prj idx val
prj _             _            = error "prj" "inconsistent valuation"

-- Convert a typed de Bruijn index to the corresponding integer
--
idxToInt :: Idx env t -> Int
idxToInt = go 0
  where go :: Int -> Idx env t -> Int
        go !n ZeroIdx       = n
        go !n (SuccIdx idx) = go (n+1) idx
