
(defclass event ()
  ((abc :initarg :abc
	:accessor :abc)))

(:abc (make-instance 'event :abc 1))

(provide 'event)
