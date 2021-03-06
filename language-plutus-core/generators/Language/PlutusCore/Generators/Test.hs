-- | This module defines functions useful for testing.

module Language.PlutusCore.Generators.Test
    ( TypeEvalCheckError (..)
    , TypeEvalCheckResult (..)
    , TypeEvalCheckM
    , typeEvalCheckBy
    , unsafeTypeEvalCheck
    , sampleTermValue
    , sampleProgramValueGolden
    , propEvaluate
    ) where

import           Language.PlutusCore
import           Language.PlutusCore.Constant
import           Language.PlutusCore.Generators.Interesting
import           Language.PlutusCore.Generators.Internal.TypedBuiltinGen
import           Language.PlutusCore.Generators.Internal.TypeEvalCheck
import           Language.PlutusCore.Generators.Internal.Utils
import           Language.PlutusCore.Pretty

import           Control.Monad.Except
import           Control.Monad.Morph
import qualified Data.Text.IO                                            as Text
import           Hedgehog                                                hiding (Size, Var, eval)
import           System.FilePath                                         ((</>))

-- | Generate a term using a given generator and check that it's well-typed and evaluates correctly.
sampleTermValue :: TermGen Size a -> IO (TermOf (Value TyName Name ()))
sampleTermValue genTerm = runQuoteSampleSucceed $ genTerm >>= liftQuote . unsafeTypeEvalCheck

-- | Generate a pair of files: @<folder>.<name>.plc@ and @<folder>.<name>.plc.golden@.
-- The first file contains a term generated by a term generator (wrapped in 'Program'),
-- the second file contains the result of evaluation of the term.
sampleProgramValueGolden
    :: String          -- ^ @folder@
    -> String          -- ^ @name@
    -> TermGen Size a  -- ^ A term generator.
    -> IO ()
sampleProgramValueGolden folder name genTerm = do
    let filePlc       = folder </> (name ++ ".plc")
        filePlcGolden = folder </> (name ++ ".plc.golden")
    TermOf term value <- sampleTermValue genTerm
    Text.writeFile filePlc       . prettyPlcDefText $ Program () (Version () 0 1 0) term
    Text.writeFile filePlcGolden $ prettyPlcDefText value

-- | A property-based testing procedure for evaluators.
-- Checks whether a term generated along with the value it's supposed to compute to
-- indeed computes to that value according to the provided evaluate.
propEvaluate
    :: (Term TyName Name () -> EvaluationResult)       -- ^ An evaluator.
    -> GenT Quote (TermOf (TypedBuiltinValue Size a))  -- ^ A term/value generator.
    -> Property
propEvaluate eval genTermOfTbv = property . hoist (return . runQuote) $ do
    termOfTbv <- forAllNoShowT genTermOfTbv
    case runQuote . runExceptT $ typeEvalCheckBy eval termOfTbv of
        Left (TypeEvalCheckErrorIllFormed err)             -> errorPlc err
        Left (TypeEvalCheckErrorIllEvaled expected actual) ->
            expected === actual  -- We know that these two are disctinct, but there is no nice way we
                                 -- can report this via 'hedgehog' except by comparing them here again.
        Right _                                            -> return ()
