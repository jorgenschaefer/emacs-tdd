;;; tdd.el --- recompile on save and indicate success in the mode line

;; Copyright (C) 2014  Jorgen Schaefer <contact@jorgenschaefer.de>

;; Author: Jorgen Schaefer <contact@jorgenschaefer.de>
;; URL: https://github.com/jorgenschaefer/emacs-tdd
;; Version: 1.0
;; Keywords: tools, processes

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; After enabling `tdd-mode', any command to save a file will run
;; `recompile' in the background. The mode line shows the status of
;; the last compilation process.

;; This is meant to be used with test-driven development:

;; - Write a test and save the file
;; - Watch the test fail as the status line indicator turns red
;; - Write code and save the file until the status line turns green
;; - Repeat

;;; Code:

(require 'compile)

(defgroup tdd nil
  "Test-Driven Development Indicator."
  :prefix "tdd-"
  :group 'productivity)

(defvar tdd-mode-line-map (let ((map (make-sparse-keymap)))
                            (define-key map [mode-line mouse-1]
                              'tdd-display-buffer)
                            map)
  "Keymap used on the mode line indicator.")

(defcustom tdd-success-symbol "✔"
  "Mode line symbol to show when tests passed."
  :type 'string
  :group 'tdd)

(defcustom tdd-success-face 'compilation-mode-line-exit
  "Face to use for `tdd-success-symbol'."
  :type 'face
  :group 'tdd)

(defcustom tdd-failure-symbol "✖"
  "Mode line symbol to show when tests failed."
  :type 'string
  :group 'tdd)

(defcustom tdd-failure-face 'compilation-mode-line-fail
  "Face to use for `tdd-failure-symbol'."
  :type 'face
  :group 'tdd)

(defcustom tdd-waiting-symbol "✱"
  "Mode line symbol to show when tests are running."
  :type 'string
  :group 'tdd)

(defcustom tdd-waiting-face 'compilation-mode-line-run
  "Face to use for `tdd-waiting-symbol'."
  :type 'face
  :group 'tdd)

(defvar tdd-mode-line-format ""
  "The mode line entry for the TDD indicator.")
(put 'tdd-mode-line-format 'risky-local-variable
     'do-show-properties-in-mode-line)

(defvar tdd-compilation-in-progress nil
  "Non-nil if we already started a compilation process.

Sadly, `get-buffer-process' does not work for preventing
duplicate compilation runs.")

(define-minor-mode tdd-mode
  "Test-driven development global minor mode.

Runs `recompile' every time a buffer is saved, and adjusts a mode
line indicator depending on the success or failure of that
compilation command."
  :global t
  (cond
   (tdd-mode
    (tdd-add-mode-line-format)
    (tdd-success)
    (add-hook 'compilation-finish-functions 'tdd-compilation-finish)
    (add-hook 'compilation-start-hook 'tdd-compilation-start)
    (add-hook 'after-save-hook 'tdd-after-save))
   (t
    (tdd-remove-mode-line-format)
    (setq tdd-mode-line-format "")
    (remove-hook 'compilation-finish-functions 'tdd-compilation-finish)
    (remove-hook 'compilation-start-hook 'tdd-compilation-start)
    (remove-hook 'after-save-hook 'tdd-after-save))))

(defun tdd-success ()
  "Set the TDD indicator to green."
  (interactive)
  (setq tdd-mode-line-format
        (propertize tdd-success-symbol
                    'face tdd-success-face
                    'keymap tdd-mode-line-map
                    'mouse-face 'mode-line-highlight
                    'help-echo (concat "Tests succeeded\n"
                                       "mouse-1: Switch to test buffer"))))

(defun tdd-failure ()
  "Set the TDD indicator to red."
  (interactive)
  (setq tdd-mode-line-format
        (propertize tdd-failure-symbol
                    'face tdd-failure-face
                    'keymap tdd-mode-line-map
                    'mouse-face 'mode-line-highlight
                    'help-echo (concat "Tests running\n"
                                       "mouse-1: Switch to test buffer"))))

(defun tdd-waiting ()
  "Set the TDD indicator to mark an ongoing compilation run."
  (interactive)
  (setq tdd-mode-line-format
        (propertize tdd-waiting-symbol
                    'face tdd-waiting-face
                    'keymap tdd-mode-line-map
                    'mouse-face 'mode-line-highlight
                    'help-echo (concat "Tests failed\n"
                                       "mouse-1: Switch to test buffer"))))

(defun tdd-display-buffer ()
  "Display the compilation buffer."
  (interactive)
  (let ((compilation-buffer (get-buffer
                             (compilation-buffer-name "compilation"
                                                      nil nil))))
    (when compilation-buffer
      (display-buffer compilation-buffer))))

(defun tdd-add-mode-line-format ()
  "Add `tdd-mode-line-format' to `mode-line-format'."
  (let ((global-mode-line (default-value 'mode-line-format)))
    (when (not (memq 'tdd-mode-line-format global-mode-line))
      (setq-default mode-line-format
                    (cons (car global-mode-line)
                          (cons 'tdd-mode-line-format
                                (cdr global-mode-line)))))))

(defun tdd-remove-mode-line-format ()
  "Add `tdd-mode-line-format' to `mode-line-format'."
  (let ((global-mode-line (default-value 'mode-line-format)))
    (when (memq 'tdd-mode-line-format global-mode-line)
      (setq-default mode-line-format
                    (delq 'tdd-mode-line-format
                          global-mode-line)))))

(defun tdd-after-save ()
  "Function run in `after-save-hook' to start the compilation."
  (when (not tdd-compilation-in-progress)
    (setq tdd-compilation-in-progress t)
    (let ((compilation-ask-about-save nil)
          (compilation-save-buffers-predicate (lambda () nil)))
      (save-window-excursion
        (recompile)))))

(defun tdd-compilation-start (proc)
  "Function run from `compilation-start-hook'."
  (setq tdd-compilation-in-progress t)
  (tdd-waiting))

(defun tdd-compilation-finish (buf msg)
  "Function run from `compilation-finish-functions'."
  (setq tdd-compilation-in-progress nil)
  (if (string-match "exited abnormally" msg)
      (tdd-failure)
    (tdd-success)))

(provide 'tdd)
;;; tdd.el ends here
