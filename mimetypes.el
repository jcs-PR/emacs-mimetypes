;;; mimetypes.el --- Guess a file's mimetype by extension

;; Copyright (C) 2020 Craig Niles

;; Author: Craig Niles <niles.c at gmail.com>
;; Maintainer: Craig Niles <niles.c at gmail.com>
;; URL: https://github.com/cniles/emacs-mimetypes
;; Package-Requires: ((emacs "25.1"))
;; Version: 0.0.1

;; This file is NOT part of GNU Emacs.

;; mimetypes is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; mimetypes is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with mimetypes.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; mimetypes provides a library for guessing mimetype by file
;; extension based on the platform.  On Windows it will search the
;; registry.  Otherwise, it will search for one of the known locations
;; that a mime.types file may exist and utilize it.

;;; Code:

(require 'seq)
(require 'subr-x)

(defvar mimetypes-known-files
  '("/etc/mime.types"
    "/etc/httpd/mime.types"
    "/etc/httpd/conf/mime.types"
    "/etc/apache/mime.types"
    "/etc/apache2/mime.types"
    "/usr/local/etc/httpd/conf/mime.types"
    "/usr/local/lib/netscape/mime.types"
    "/usr/local/etc/httpd/conf/mime.types"
    "/usr/local/etc/mime.types")
  "List of known mime.types file locations.")

(defun mimetypes--first-known-file (files)
  "Return the first file from a list of file names FILES that exists."
  (if files
      (let ((f-name (car files)))
	(if (file-exists-p f-name) f-name
	  (mimetypes--first-known-file (cdr files))))))

(defun mimetypes--trim-extension (extension)
  "Remove period/whitespace from EXTENSION."
  (string-trim extension "[. \t\n\r]+"))

(defun mimetypes--read-registry (key-name value-name)
  "Read KEY-NAME and VALUE-NAME from the Windows registry."
  (with-temp-buffer
    (let ((result (call-process "reg.exe" nil t nil "query" key-name "/v" value-name)))
      (if (equal 0 result) (split-string (buffer-string))
	nil))))

(defun mimetypes--find-in-registry (extension)
  "Search the registry for a mime type for EXTENSION."
  (car (last (mimetypes--read-registry
	      (format "HKEY_LOCAL_MACHINE\\Software\\Classes\\.%s" (mimetypes--trim-extension extension))
	      "Content Type"))))

(defun mimetypes--ignored-line-p (line)
  "Check if the mime.types line LINE is a comment or empty."
  (setq line (string-trim line))
  (not (null (or (string= line "") (string-match "^#" line)))))

(defun mimetypes--line-has-extension (line extension)
  "Check if mime.types line LINE has a mime type for EXTENSION."
  (not (null (seq-contains (cdr (split-string line)) extension #'string=))))

(defun mimetypes--find-in-file (extension file-name)
  "Check for EXTENSION in mime.types file FILE-NAME."
  (with-temp-buffer
    (insert-file-contents-literally file-name)
    (mimetypes--find-in-buffer (downcase (mimetypes--trim-extension extension)))))

(defun mimetypes--find-in-buffer (extension)
  "Check for EXTENSION in mime.types content in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (while
	(let ((current-line
	       (string-trim (buffer-substring-no-properties (line-beginning-position) (line-end-position)))))
	  (if (< (point) (point-max))
	      (or (mimetypes--ignored-line-p current-line)
		  (not (mimetypes--line-has-extension current-line extension)))))
      (forward-line))
    (car (split-string (buffer-substring-no-properties (line-beginning-position) (line-end-position))))))

(provide 'mimetypes)
;;; mimetypes.el ends here
