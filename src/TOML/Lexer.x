{
{-# LANGUAGE Trustworthy #-}
{-|
Module      : TOML.Lexer
Description : /Internal:/ Lexer for TOML generated by Alex
Copyright   : (c) Eric Mertens, 2017
License     : ISC
Maintainer  : emertens@gmail.com

Lexer for TOML generated by Alex. Errors are reported in the resulting
token list with 'Error'. As much as possible this module only contains
generated code. The rest of the implementation is in "LexerUtils".
-}
module TOML.Lexer (scanTokens) where

import           Data.Text (Text)
import qualified Data.Text as Text

import           TOML.LexerUtils
import           TOML.Tokens
import           TOML.Located

}

$alpha          = [A-Z a-z]
$digit          = [0-9]
$hexdigit       = [0-9 a-f A-F]

@decimal        = $digit+

@barekey        = ($alpha | $digit | \_ | \-)+

@newline        = \r? \n

@fractpart      = $digit+ (\_ $digit+)*
@integer        = [\-\+]? (0 | [1-9] $digit* (\_ $digit+)*)
@double         = @integer (\. @fractpart)? ([eE] [\-\+]? $digit+ (\_ $digit+)*)?
@inf            = [\-\+]? "inf"
@nan            = [\-\+]? "nan"


@day            = $digit+   \- $digit{2} \- $digit{2}
@timeofday      = $digit{2} \: $digit{2} \: $digit{2} (\. $digit*)?
@localtime      = @day (T | t | $white) @timeofday
@zonedtime      = @localtime ( $alpha | [\+\-] $digit{2} \:? $digit{2} )


toml :-

<0> {
$white+                 ;
"#" .*                  ;

"{"                     { token_ LeftBraceToken         }
"}"                     { token_ RightBraceToken        }
"["                     { token_ LeftBracketToken       }
"]"                     { token_ RightBracketToken      }
","                     { token_ CommaToken             }
"."                     { token_ PeriodToken            }
"="                     { token_ EqualToken             }
@integer                { token integer                 }
@double                 { token double                  }
@inf                    { token InfToken                }
@nan                    { token NanToken                }
"true"                  { token_ TrueToken              }
"false"                 { token_ FalseToken             }
@localtime              { token localtime               }
@zonedtime              { token zonedtime               }
@timeofday              { token timeofday               }
@day                    { token day                     }
@barekey                { token bareKeyToken            }

'''      @newline ?     { startString mlsq              }
\" \" \" @newline ?     { startString mldq              }
'                       { startString slsq              }
\"                      { startString sldq              }
} -- end of <0>

<mlsq> '''              { endString                     }
<mldq> \" \" \"         { endString                     }
<slsq> '                { endString                     }
<sldq> \"               { endString                     }

<mlsq,mldq> @newline    { emitChar                      }
<sldq,mldq> {
\\ b                    { emitChar' '\b'                }
\\ t                    { emitChar' '\t'                }
\\ n                    { emitChar' '\n'                }
\\ f                    { emitChar' '\f'                }
\\ r                    { emitChar' '\r'                }
\\ \"                   { emitChar' '"'                 }
\\ \\                   { emitChar' '\\'                }
\\ u $hexdigit{4}       { emitUnicodeChar               }
\\ U $hexdigit{8}       { emitUnicodeChar               }
\\ @newline $white *    ;
\\                      { token_ (ErrorToken BadEscape) }
}

<sldq,slsq,mldq,mlsq> . { emitChar                      }

{
-- | Produce a token stream from an input file. The token
-- stream will always be terminated by an 'ErrorToken' or
-- 'EofToken'.
scanTokens ::
  Text            {- ^ Source text          -} ->
  [Located Token] {- ^ Tokens with position -}
scanTokens str = go (Located startPos str) InNormal
  where
  go inp st =
    case alexScan inp (lexerModeInt st) of
      AlexEOF                -> eofAction (locPosition inp) st
      AlexError inp'         -> errorAction inp'
      AlexSkip  inp' _       -> go inp' st
      AlexToken inp' len act -> case act (fmap (Text.take len) inp) st of
                                  (st', xs) -> xs ++ go inp' st'

}
