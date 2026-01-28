;;; tyche.el --- Emacs integration for Tyche property-based testing tool -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Rick Lupton
;; URL: https://github.com/ricklupton/emacs-tyche
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (websocket "1.13"))
;; Keywords: tools, testing, property-based-testing

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Tyche is a tool that helps developers understand the effectiveness
;; of their property-based tests.  This package provides Emacs integration
;; that works similarly to the VS Code extension bundled with Tyche.
;;
;; Features:
;; - Watch for changes to hypothesis output folder
;; - Read JSON files from the output
;; - Display results in a web view
;; - WebSocket server for communication with the web UI
;;
;; Usage:
;; 1. Run M-x tyche-activate to activate Tyche for the current project
;; 2. The package will watch for changes in .hypothesis/observed/*.jsonl
;; 3. Results are displayed in a browser automatically

;;; Code:

(require 'filenotify)
(require 'json)
(require 'url)

;; Soft dependency on websocket
(unless (require 'websocket nil t)
  (display-warning 'tyche
                   "websocket.el is not installed. WebSocket functionality will not be available.
Please install it via: M-x package-install RET websocket RET"
                   :warning))

;;; Customization

(defgroup tyche nil
  "Emacs integration for Tyche property-based testing tool."
  :group 'tools
  :prefix "tyche-")

(defcustom tyche-websocket-port 8181
  "Port for the Tyche WebSocket server."
  :type 'integer
  :group 'tyche)

(defcustom tyche-observation-globs
  '("**/.hypothesis/observed/*.jsonl"
    "**/.quickcheck/observations/*.jsonl")
  "Glob patterns for finding observation files."
  :type '(repeat string)
  :group 'tyche)

(defcustom tyche-webview-url "http://localhost:3000"
  "URL for the Tyche web view.
This should point to the tyche-extension webview server.
You can also use the deployed version at https://tyche-pbt.github.io/tyche-extension/"
  :type 'string
  :group 'tyche)

;;; Internal variables

(defvar tyche--project-root nil
  "Root directory of the current Tyche project.")

(defvar tyche--file-watchers nil
  "List of active file watchers.")

(defvar tyche--websocket-server nil
  "WebSocket server instance.")

(defvar tyche--websocket-clients nil
  "List of connected WebSocket clients.")

(defvar tyche--pending-files nil
  "List of files with pending changes.")

(defvar tyche--pending-timer nil
  "Timer for debouncing file changes.")

(defvar tyche--observation-buffer nil
  "Buffer for storing accumulated observations.")

;;; WebSocket server

(defun tyche--websocket-on-message (_ws frame)
  "Handle incoming WebSocket message from client WS with FRAME."
  (let ((msg (websocket-frame-text frame)))
    (message "Tyche: Received message: %s" msg)))

(defun tyche--websocket-on-close (ws)
  "Handle WebSocket close event for client WS."
  (setq tyche--websocket-clients
        (delq ws tyche--websocket-clients))
  (message "Tyche: Client disconnected"))

(defun tyche--websocket-on-open (ws)
  "Handle new WebSocket connection WS."
  (push ws tyche--websocket-clients)
  (message "Tyche: Client connected")
  ;; Send any buffered observations to the new client
  (when tyche--observation-buffer
    (tyche--send-to-websocket-clients tyche--observation-buffer)))

(defun tyche--start-websocket-server ()
  "Start the Tyche WebSocket server."
  (unless (featurep 'websocket)
    (user-error "websocket.el is not available. Please install it via: M-x package-install RET websocket RET"))
  (when tyche--websocket-server
    (tyche--stop-websocket-server))
  (setq tyche--websocket-server
        (websocket-server
         tyche-websocket-port
         :host 'local
         :on-message #'tyche--websocket-on-message
         :on-open #'tyche--websocket-on-open
         :on-close #'tyche--websocket-on-close))
  (message "Tyche: WebSocket server started on port %d" tyche-websocket-port))

(defun tyche--stop-websocket-server ()
  "Stop the Tyche WebSocket server."
  (when tyche--websocket-server
    ;; Close all client connections
    (dolist (client tyche--websocket-clients)
      (websocket-close client))
    (setq tyche--websocket-clients nil)
    ;; Close the server
    (websocket-server-close tyche--websocket-server)
    (setq tyche--websocket-server nil)
    (message "Tyche: WebSocket server stopped")))

(defun tyche--send-to-websocket-clients (data)
  "Send DATA to all connected WebSocket clients."
  (dolist (client tyche--websocket-clients)
    (condition-case err
        (websocket-send-text client data)
      (error
       (message "Tyche: Error sending to client: %s" err)
       (setq tyche--websocket-clients (delq client tyche--websocket-clients))))))

;;; File watching

(defun tyche--find-files-matching-globs (globs)
  "Find all files matching GLOBS in the project root."
  (let ((files nil)
        (default-directory tyche--project-root))
    (dolist (glob globs)
      ;; Convert glob pattern to find command
      ;; Simple implementation - in real use might need more sophisticated glob handling
      (let* ((pattern (replace-regexp-in-string "\\*\\*/" "" glob))
             (pattern (replace-regexp-in-string "\\*" ".*" pattern))
             (find-cmd (format "find . -type f -path './%s' 2>/dev/null" pattern)))
        (with-temp-buffer
          (when (zerop (call-process-shell-command find-cmd nil t))
            (goto-char (point-min))
            (while (not (eobp))
              (let ((file (buffer-substring-no-properties
                          (line-beginning-position)
                          (line-end-position))))
                (when (> (length file) 0)
                  (push (expand-file-name file tyche--project-root) files)))
              (forward-line 1))))))
    (nreverse files)))

(defun tyche--read-jsonl-files (files)
  "Read and concatenate JSONL FILES into a single string."
  (let ((content ""))
    (dolist (file files)
      (when (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (setq content (concat content (buffer-string))))))
    content))

(defun tyche--process-pending-files ()
  "Process pending file changes."
  (when tyche--pending-files
    (let* ((files (delete-dups tyche--pending-files))
           (content (tyche--read-jsonl-files files)))
      (setq tyche--pending-files nil)
      (setq tyche--observation-buffer content)
      ;; Send to all connected clients
      (when (> (length content) 0)
        (tyche--send-to-websocket-clients content)
        (message "Tyche: Sent %d bytes to %d client(s)"
                (length content)
                (length tyche--websocket-clients))))))

(defun tyche--file-change-callback (event)
  "Handle file system EVENT for observed files."
  (let ((file (nth 2 event))
        (action (nth 1 event)))
    (when (memq action '(changed created))
      ;; Add to pending files
      (push file tyche--pending-files)
      ;; Debounce: reset timer
      (when tyche--pending-timer
        (cancel-timer tyche--pending-timer))
      (setq tyche--pending-timer
            (run-with-timer 0.6 nil #'tyche--process-pending-files)))))

(defun tyche--watch-directory (dir _pattern)
  "Watch DIR for files matching PATTERN."
  (when (file-directory-p dir)
    (let ((watcher (file-notify-add-watch
                   dir
                   '(change)
                   #'tyche--file-change-callback)))
      (push watcher tyche--file-watchers))))

(defun tyche--setup-file-watchers ()
  "Set up file watchers for observation files."
  (let ((hypothesis-dir (expand-file-name ".hypothesis/observed" tyche--project-root))
        (quickcheck-dir (expand-file-name ".quickcheck/observations" tyche--project-root)))
    ;; Watch .hypothesis/observed directory
    (when (file-directory-p hypothesis-dir)
      (tyche--watch-directory hypothesis-dir "\\.jsonl$"))
    ;; Watch .quickcheck/observations directory
    (when (file-directory-p quickcheck-dir)
      (tyche--watch-directory quickcheck-dir "\\.jsonl$"))
    (message "Tyche: Watching for changes in observation directories")))

(defun tyche--stop-file-watchers ()
  "Stop all file watchers."
  (dolist (watcher tyche--file-watchers)
    (file-notify-rm-watch watcher))
  (setq tyche--file-watchers nil)
  (when tyche--pending-timer
    (cancel-timer tyche--pending-timer)
    (setq tyche--pending-timer nil)))

;;; Web view

(defun tyche--open-webview ()
  "Open the Tyche web view in a browser."
  (browse-url tyche-webview-url)
  (message "Tyche: Opened web view at %s" tyche-webview-url))

;;; Public commands

;;;###autoload
(defun tyche-activate (&optional project-root)
  "Activate Tyche for the current project.
Optional PROJECT-ROOT specifies the project root directory.
If not provided, uses `project-current' or `default-directory'."
  (interactive)
  (let ((root (or project-root
                  (when (fboundp 'project-root)
                    (when-let ((proj (project-current)))
                      (project-root proj)))
                  default-directory)))
    (setq tyche--project-root (expand-file-name root))
    (message "Tyche: Activating for project at %s" tyche--project-root)
    
    ;; Start WebSocket server
    (tyche--start-websocket-server)
    
    ;; Set up file watchers
    (tyche--setup-file-watchers)
    
    ;; Load existing observation files
    (let* ((files (tyche--find-files-matching-globs tyche-observation-globs))
           (content (tyche--read-jsonl-files files)))
      (when (> (length content) 0)
        (setq tyche--observation-buffer content)
        (message "Tyche: Loaded %d existing observation file(s)" (length files))))
    
    ;; Open web view
    (tyche--open-webview)))

;;;###autoload
(defun tyche-deactivate ()
  "Deactivate Tyche for the current project."
  (interactive)
  (tyche--stop-file-watchers)
  (tyche--stop-websocket-server)
  (setq tyche--project-root nil)
  (setq tyche--observation-buffer nil)
  (message "Tyche: Deactivated"))

;;;###autoload
(defun tyche-refresh ()
  "Refresh the Tyche view by reloading all observation files."
  (interactive)
  (when tyche--project-root
    (let* ((files (tyche--find-files-matching-globs tyche-observation-globs))
           (content (tyche--read-jsonl-files files)))
      (when (> (length content) 0)
        (setq tyche--observation-buffer content)
        (tyche--send-to-websocket-clients content)
        (message "Tyche: Refreshed with %d observation file(s)" (length files))))
    (unless tyche--project-root
      (message "Tyche: Not activated. Run M-x tyche-activate first"))))

;;;###autoload
(defun tyche-open-webview ()
  "Open the Tyche web view in a browser."
  (interactive)
  (tyche--open-webview))

(provide 'tyche)

;;; tyche.el ends here
