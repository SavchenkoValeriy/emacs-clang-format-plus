;;; clang-format+.el --- Minor mode for automatic clang-format application -*- lexical-binding: t; -*-

;; Copyright (c) 2019 Valeriy Savchenko (GNU/GPL Licence)

;; Authors: Valeriy Savchenko <sinmipt@gmail.com>
;; URL: https://github.com/SavchenkoValeriy/emacs-clang-format-plus
;; Version: 1.0.0
;; Package-Requires: ((emacs "25.1") (clang-format "20180406.1514"))
;; Keywords: c c++ clang-format

;; This file is NOT part of GNU Emacs.

;; jeison is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; jeison is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with jeison.
;; If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Minor mode for applying clang-format automatically on save.
;; It can also apply clang-format to the modified parts of the region only
;; and try to be smart about it.

;;; Code:

(require 'cc-cmds)
(require 'clang-format)
(require 'cl-lib)

(defgroup clang-format+ nil
  "Minor mode for automatic clang-format application"
  :group 'convenience)

(defcustom clang-format+-apply-to-modifications-only
  t
  "Format only modified parts of the buffer or the whole buffer."
  :type 'boolean
  :group 'clang-format+)

(defcustom clang-format+-apply-to-modified-definition
  t
  "Format the whole class or function that has been modified.

Makes a difference only when `clang-format+-apply-to-modifications-only' is t."
  :type 'boolean
  :group 'clang-format+)

(defcustom clang-format+-offset-modified-region
  0
  "Number of lines to add to the modified region.

Clang-format+ adds it both to the beggining and to the end of the region.
Used only when `clang-format+-apply-to-modified-definition' is nil or
when not inside of the function."
  :type 'integer
  :group 'clang-format+)

(defvar clang-format+-saved)

(defmacro clang-format+-with-save (&rest forms)
  "Run FORMS with restriction and excursion saved once."
  (declare (debug (body)))
  `(if (and (boundp 'clang-format+-saved)
            clang-format+-saved)
       (progn
         ,@forms)
     (let ((clang-format+-saved t))
       (save-excursion
         (save-restriction
           ,@forms)))))

(defun clang-format+-map-changes (func &optional start-position end-position)
  "Call FUNC with each changed region (START-POSITION END-POSITION).

This simply uses an end marker since we are modifying the buffer
in place."
  ;; See `hilit-chg-map-changes' and `ws-butler-map-changes'.
  (let ((start (or start-position (point-min)))
        (limit (copy-marker (or end-position (point-max))))
        prop end)
    (while (and start (< start limit))
      (setq prop (get-text-property start 'clang-format+-chg))
      (setq end (text-property-not-all start limit 'clang-format+-chg prop))
      (if prop
          (funcall func prop start (or end limit)))
      (setq start end))
    (set-marker limit nil)))

(defun clang-format+-before-save ()
  "Run ‘clang-format’ on the current buffer."
  (if clang-format+-apply-to-modifications-only
      (clang-format+-apply-to-modifications)
    (clang-format-buffer)))

(defun clang-format+-apply-to-modifications ()
  "Apply ‘clang-format’ to modified parts of the current buffer."
  (let ((processed nil))
    (clang-format+-map-changes
     (lambda (_prop beg end)
       (setq beg (clang-format+-get-region-beginning beg)
             end (clang-format+-get-region-end end))
       ;; We run clang-format for every little change to the code N times,
       ;; which is exactly N-1 times more than needed.
       ;; Unfortunately, while clang-format executable accepts many regions
       ;; as its input, clang-format-region function accepts only one.
       ;;
       ;; And even though we run it this many times, we don't want
       ;; at least running it more than once on the same piece of code.
       ;;
       ;; For this purpose, we check that this region is not processed yet...
       (unless (clang-format+-in-processed processed beg end)
         ;; no need to track changes made by clang-format
         (remove-hook 'after-change-functions
                      'clang-format+-after-change t)
         (clang-format-region beg end)
         ;; ...and remember processed ones
         (add-to-list 'processed (cons beg end))
         (add-hook 'after-change-functions
                   #'clang-format+-after-change t t))))))

(defun clang-format+-in-processed (processed beg end)
  "Check if the given region BEG END is in PROCESSED.

PROCESSED should be a list of cons pairs denoting begins
and ends of already processed regions."
  (cl-some (lambda (region) (<= (car region) beg end (cdr region)))
           processed))

(defun clang-format+-get-region-beginning (pointer)
  "Get where the reformatting region should start for the POINTER."
  (clang-format+-get-region-internal pointer
                                     #'c-beginning-of-defun
                                     #'previous-line))

(defun clang-format+-get-region-end (pointer)
  "Get where the reformatting region should end for the POINTER."
  ;; Subtract one from end to overcome Emacs bug #17784, since we
  ;; always expand to end of line anyway, this should be OK.
  (clang-format+-get-region-internal (1- pointer)
                                     #'c-end-of-defun
                                     #'next-line))

(defun clang-format+-get-region-internal (pointer
                                          definition-move
                                          fallback-move)
  "Move from POINTER by one of the given move actions and return the new point.

Only returns a new point, not persistently moves there.

DEFINITION-MOVE will be used if POINTER is inside of a definition.
DEFINITION-MOVE shouldn't take any arguments.

FALLBACK-MOVE will be used if POINTER is outside of the definition,
or when modification of the whole definition is not allowed."
  (save-excursion
    (goto-char pointer)
    (if (and clang-format+-apply-to-modified-definition
             (clang-format+-inside-of-enclosing-definition-p))
        (funcall definition-move)
      (funcall fallback-move clang-format+-offset-modified-region))
    (point)))

(defun clang-format+-inside-of-enclosing-definition-p ()
  "Check if the pointer inside of the definition."
  ;; Adding new functions or classes into namespaces is a normal practice,
  ;; and we shouldn't reformat the WHOLE namespace because of this.
  ;; That's why we don't want to consider it as a definition.
  (unless (clang-format+-inside-of-namespace-p)
    (save-excursion
      (let ((original (point))
            (start (progn (c-beginning-of-defun) (point)))
            (end (progn (c-end-of-defun) (point))))
        (<= start original end)))))

(defun clang-format+-inside-of-namespace-p ()
  "Check if the pointer inside of a namespace."
  ;; this code is highly inspired by the code
  ;; from `c-show-syntactic-information'
  (let* ((syntax-stack (if (boundp 'c-syntactic-context)
                           ;; Use `c-syntactic-context' in the same way as
                           ;; `c-indent-line', to be consistent.
                           c-syntactic-context
                         (c-save-buffer-state nil
                           (c-guess-basic-syntax))))
         (top-level-context (caar syntax-stack)))
    (equal top-level-context 'innamespace)))

(defun clang-format+-clear-properties ()
  "Clear all clang-format+ text properties in buffer."
  (with-silent-modifications
    (clang-format+-map-changes (lambda (_prop start end)
                                 (remove-list-of-text-properties
                                  start end '(clang-format+-chg))))))

(defun clang-format+-after-change (beg end length-before)
  "Remember buffer modification.

Mark text from BEG to END as modification.
LENGTH-BEFORE stands for the length of the text before modification."
  (let ((type (if (and (= beg end) (> length-before 0))
                  'delete
                'chg)))
    (if undo-in-progress
        ;; add back deleted text during undo
        (if (and (zerop length-before)
                 (> end beg)
                 (eq (get-text-property end 'clang-format+-chg) 'delete))
            (remove-list-of-text-properties end (1+ end) '(clang-format+-chg)))
      (with-silent-modifications
        (when (eq type 'delete)
          (setq end (min (+ end 1) (point-max))))
        (put-text-property beg end 'clang-format+-chg type)))))

(defun clang-format+-after-save ()
  "Restore trimmed whitespace before point."
  (clang-format+-clear-properties))

;;;###autoload
(define-minor-mode clang-format+-mode
  "Run clang-format on save."
  :lighter " cf+"
  :group 'clang-format+
  (if clang-format+-mode
      (progn
        (add-hook 'after-change-functions #'clang-format+-after-change t t)
        (add-hook 'before-save-hook #'clang-format+-before-save t t)
        (add-hook 'after-save-hook #'clang-format+-after-save t t)
        (add-hook 'after-revert-hook #'clang-format+-after-save t t)
        (add-hook 'edit-server-done-hook #'clang-format+-before-save t t))
    (remove-hook 'after-change-functions 'clang-format+-after-change t)
    (remove-hook 'before-save-hook 'clang-format+-before-save t)
    (remove-hook 'after-save-hook 'clang-format+-after-save t)
    (remove-hook 'after-revert-hook 'clang-format+-after-save t)
    (remove-hook 'edit-server-done-hook 'clang-format+-before-save t)))

(provide 'clang-format+)
;;; clang-format+.el ends here
