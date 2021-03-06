module Test.Main where

import Prelude

import Control.Alt ((<|>))
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Data.Either (Either(..))
import Data.List (List)
import Data.List as L
import Data.Map as M
import Data.Tuple (Tuple(..))
import Routing (match)
import Routing.Match (Match, list)
import Routing.Match.Class (bool, end, int, lit, num, str, param, params)
import Test.Assert (ASSERT, assert')

data FooBar
  = Foo Number (M.Map String String)
  | Bar Boolean String
  | Baz (List Number)
  | Quux Int
  | Corge String
  | End Int

derive instance eqFooBar :: Eq FooBar

instance showFooBar :: Show FooBar where
  show (Foo num q) = "(Foo " <> show num <> " " <> show q <> ")"
  show (Bar bool str) = "(Bar " <> show bool <> " " <> show str <> ")"
  show (Baz lst) = "(Baz " <> show lst <> ")"
  show (Quux i) = "(Quux " <> show i <> ")"
  show (Corge str) = "(Corge " <> show str <> ")"
  show (End i) = "(End " <> show i <> ")"

routing :: Match FooBar
routing =
  Foo <$> (lit "foo" *> num) <*> params
    <|> Bar <$> (lit "bar" *> bool) <*> (param "baz")
    <|> Quux <$> (lit "" *> lit "quux" *> int)
    <|> Corge <$> (lit "corge" *> str)
    -- Order matters here.  `list` is greedy, and `end` wont match after it
    <|> End <$> (lit "" *> int <* end)
    <|> Baz <$> (list num)


main :: Eff (assert :: ASSERT, console :: CONSOLE) Unit
main = do
  assertEq (match routing "foo/12/?welp='hi'&b=false") (Right (Foo 12.0 (M.fromFoldable [Tuple "welp" "'hi'", Tuple "b" "false"])))
  assertEq (match routing "foo/12?welp='hi'&b=false") (Right (Foo 12.0 (M.fromFoldable [Tuple "welp" "'hi'", Tuple "b" "false"])))
  assertEq (match routing "bar/true?baz=test") (Right (Bar true "test"))
  assertEq (match routing "bar/false?baz=%D0%B2%D1%80%D0%B5%D0%BC%D0%B5%D0%BD%D0%BD%D1%8B%D0%B9%20%D1%84%D0%B0%D0%B9%D0%BB") (Right (Bar false "временный файл"))
  assertEq (match routing "corge/test") (Right (Corge "test"))
  assertEq (match routing "corge/%D0%B2%D1%80%D0%B5%D0%BC%D0%B5%D0%BD%D0%BD%D1%8B%D0%B9%20%D1%84%D0%B0%D0%B9%D0%BB") (Right (Corge "временный файл"))
  assertEq (match routing "/quux/42") (Right (Quux 42))
  assertEq (match routing "123/") (Right (Baz (L.fromFoldable [123.0])))
  assertEq (match routing "/1") (Right (End 1))
  assertEq (match routing "foo/0/?test=a/b/c") (Right (Foo 0.0 (M.fromFoldable [Tuple "test" "a/b/c"])))

assertEq
  :: forall a eff
  . Eq a
  => Show a
  => a
  -> a
  -> Eff (assert :: ASSERT, console :: CONSOLE | eff) Unit
assertEq actual expected
  | actual /= expected = assert' ("Equality assertion failed\n\nActual: " <> show actual <> "\n\nExpected: " <> show expected) false
  | otherwise = log ("Equality assertion passed for " <> show actual)
