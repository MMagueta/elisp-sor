;;; main.el --- Test project with one dependency  -*- lexical-binding: t -*-

;; Version: 1.0
;; Homepage: https://example.com/

;;; Commentary:

;; Comments to make linters happy.

;;; Code:

(defun fibonacci (n)
  (let ((a 0)
	(b 1)
	(aux nil))
    (dotimes (_ n)
      (setf aux a)
      (setf a b)
      (setf b (+ aux b)))
    a))

(print (fibonacci-iter 10))

(provide 'main)

;;; main.el ends here
