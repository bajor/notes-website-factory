module Main (main) where

import Factory.Pipeline (runCommand)

-- The executable is intentionally tiny. All interesting decisions live in
-- named library modules, where they can be tested without starting a process.
main :: IO ()
main = runCommand
