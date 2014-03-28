;;; org-printer.el --- Print buffer with `org-mode' exporter

;; Copyright (C) 2014 Tsunenobu Kai

;; Author: Tsunenobu Kai <kbkbkbkb1@gmail.com>
;; URL: https://github.com/kbkbkbkb1/org-printer
;; Version: 0.0.1
;; Package-Requires: ((org "8.0.0"))
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'org-capture)

(defgroup org-printer nil
  "Print buffer with `org-mode' exporter"
  :group 'org
  :prefix "org-printer-")

;;; User customizable variables
(defcustom org-printer-template "\
#+TITLE: 
#+BEGIN_EXAMPLE
%(eval org-printer-content)
#+END_EXAMPLE"
  "Template string for printing.

\"%(...)\" in this variable is evaluated as S-expression like
`org-capture-templates'. This variable should include
\"%(eval org-printer-content)\" since the content you want to print
is expanded there.

If `org-printer-template-file' is non-nil, this variable is ignored.")

(defcustom org-printer-template-file nil
  "Template file for printing.

\"%(...)\" in this file is evaluated as S-expression like
`org-capture-templates'. This file should include
\"%(eval org-printer-content)\" since the content you want to print
is expanded there.")

(defcustom org-printer-directory nil
  "Save a exporeted html in this directory.

If this variable is nil, save in a temporal directory.")

(defcustom org-printer-environment
  '((org-export-show-temporary-export-buffer nil)
    (org-html-postamble nil))
  "List of a variable and its value which controls org exporter.

These variables are let-binded only in `org-printer' commands.")

;;; Commands
;;;###autoload
(defun org-printer-print-buffer (&optional buffer)
  "Export buffer BUFFER as html and open in browser.

If executed with prefix arg, read a buffer name from minibuffer.
If BUFFER is omitted, use the current buffer."
  (interactive (list (if current-prefix-arg
                         (read-buffer "Print buffer: " (buffer-name) t)
                       (current-buffer))))
  (with-current-buffer (or buffer (current-buffer))
    (org-printer-print-region (point-min) (point-max))))

;;;###autoload
(defun org-printer-print-region (start end)
  "Export current region as html and open in browser."
  (interactive "r")
  (or start end (error "The mark is not set now, so there is no region"))
  (let* ((org-printer-buffer (current-buffer))
         (org-printer-filename (replace-regexp-in-string
                                "^\\*\\|\\*$" "!" (buffer-name)))
         (org-printer-content (buffer-substring-no-properties start end))
         (html-file (expand-file-name (concat org-printer-filename ".html")
                                      (or org-printer-directory (getenv "TEMP") "/tmp")))
         )
    ;; Escape special strings ("*", "#+") in `org-mode'
    (setq org-printer-content
          (with-temp-buffer
            (insert org-printer-content)
            (goto-char (point-min))
            (while (re-search-forward "^\\s-*\\(#\\+\\)" nil t)
              (replace-match ",\\1" nil nil nil 1))
            (goto-char (point-min))
            (while (re-search-forward "^\\*+ " nil t)
              (replace-match ",\\&"))
            (buffer-string)))
    ;; Insert the template, expand S-expression and export it
    (with-temp-buffer
      (if org-printer-template-file
          (insert-file-contents org-printer-template-file)
        (insert org-printer-template))
      (org-capture-expand-embedded-elisp)
      (with-org-printer-environment (org-html-export-as-html)))
    ;; Save exported html and open in browser
    (with-current-buffer "*Org HTML Export*"
      (set-visited-file-name html-file t)
      (let ((coding-system-for-write 'utf-8-unix))
        (write-region (point-min) (point-max) html-file))
      (set-buffer-modified-p nil)
      (kill-buffer))
    (org-open-file html-file)))

(defmacro with-org-printer (&rest body)
  "Eval BODY in a buffer printed with `org-printer' commands.

Use this macro only in a template of `org-printer' to get
informations about a buffer printed with `org-printer' commands."
  `(with-current-buffer (or org-printer-buffer
                            (error "Use this macro only in a template of `org-printer'"))
     ,@body))

(defmacro with-org-printer-environment (&rest body)
  `(let ,org-printer-environment
     ,@body))

(provide 'org-printer)
;;; org-printer.el ends here
