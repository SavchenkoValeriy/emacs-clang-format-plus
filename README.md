# clang-format+ [![Build Status](https://travis-ci.org/SavchenkoValeriy/emacs-clang-format-plus.svg?branch=master)](https://travis-ci.org/SavchenkoValeriy/emacs-clang-format-plus) [![MELPA](https://melpa.org/packages/clang-format+-badge.svg)](https://melpa.org/#/clang-format%2B)

## Description

*clang-format+* is a small package aimed at improving the user experience of using [clang-format](https://clang.llvm.org/docs/ClangFormat.html) in Emacs. 

The existing package ([clang-format.el](https://llvm.org/svn/llvm-project/cfe/trunk/tools/clang-format/clang-format.el)) provides a wrapper around the CLI allowing its users to format buffers and regions. The workflow it suggests is a bit too manual, so custom `before-save-hook`s and then `minor-mode`s come to play. *clang-format+* joins all these customizations in order to remove all the duplicated ad-hocs.

*clang-format+* defines a minor mode `clang-format+-mode`, which applies **clang-format** on save. It can also apply **clang-format** to the modified parts of the region only and try to be smart about it.

## Installation

### Install from MELPA

You can install *clang-format+* from MELPA by simply executing the following command:

<kbd>M-x package-install [RET] clang-format+ [RET]</kbd>

### Install using Quelpa

[Quelpa](https://framagit.org/steckerhalter/quelpa "Quelpa") gives you an ability to install Emacs packages directly from remote git repos. I recommend using it with [quelpa-use-package](https://framagit.org/steckerhalter/quelpa-use-package#installation) if you already use [use-package](https://github.com/jwiegley/use-package).

Here how it's done:
``` emacs-lisp
(use-package clang-format+
  :quelpa (clang-format+
           :fetcher github
           :repo "SavchenkoValeriy/emacs-clang-format-plus"))
```

### Install manually

First, install **clang-format.el** either from MELPA:

<kbd>M-x package-install [RET] clang-format [RET]</kbd>

or [manually](https://clang.llvm.org/docs/ClangFormat.html#emacs-integration).

After that you should clone this repo and add the following code to you `init.el` file:

``` emacs-lisp
(use-package clang-format+
  :load-path "<path/to/my/cloned/clang-format+/directory>")
```

### Setting up a hook

You can use *clang-format+* for all C/C++ projects you edit:

``` emacs-lisp
(add-hook 'c-mode-common-hook #'clang-format+-mode)
```

This will enable automatic formatting of C/C++ files in source trees with a [`.clang-format`](https://clang.llvm.org/docs/ClangFormatStyleOptions.html) (or `_clang-format`) file, or *all* C/C++ files if the variable `clang-format-style` is set to something else than "file". You can set `clang-format+-always-enable` to `t` to force formatting; then the default LLVM style will be used if not specified otherwise.


### Project-level hook

If you don't want to enable formatting for all projects with a `.clang-format`/`_clang-format` file, you can do it selectively by adding a [.dir-locals.el](https://www.gnu.org/software/emacs/manual/html_node/emacs/Directory-Variables.html) file in the root directory of your project with the following code inside:

``` emacs-lisp
((c++-mode . ((mode . clang-format+))))
```

## Customization

*clang-format+* defines these variables that the user can tweak:

- `clang-format+-apply-to-modifications-only` defines whether **clang-format** should be applied to the whole buffer or only to the modified parts of it (`t` by default)
- `clang-format+-apply-to-modified-definition` defines whether **clang-format** should format all definitions (functions/classes/etc.) containing modifications (`t` by default). *clang-format+* enlarges modified areas to their enclosing definitions so the formatting looks more consistent.
- `clang-format+-offset-modified-region` defines a number of extra lines added *before* and *after* modified regions to be formatted (`0` by default). If `clang-format+-apply-to-modified-definition` is `t` it will be applied only when outside of definitions.
- `clang-format+-always-enable` defines whether to enable formatting even if a style hasn't been selected. If `clang-format+-always-enable` is `nil` (which is the default), formatting will be enabled if there is a `.clang-format`/`_clang-format` file in the source tree or if `clang-format-style` is set to something else than "file". If non-`nil`, formatting will always be enabled.

## Contribute

All contributions are most welcome!

It might include any help: bug reports, questions on how to use it, feature suggestions, and documentation updates.

## Tributes

Many thanks to the authors of [clang-format](https://clang.llvm.org/docs/ClangFormat.html).

*clang-format+* is pretty much a direct clone of the [ws-butler](https://github.com/lewang/ws-butler) package in the way it tracks changes, which in its turn copies this mechanism from [highlight-changes-mode](https://github.com/emacs-mirror/emacs/blob/master/lisp/hilit-chg.el) (probably we should make a mode that will be used as a base for all other modes). Please, check out those nice modes as well.

## License

[GPL-3.0](./LICENSE)
