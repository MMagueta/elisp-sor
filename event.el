
(defclass event ()
  ((name :initarg :name
	 :accessor :name)
   (content :initarg :content
	    :accessor :content)))

(defclass state ()
  ((name :initarg :name
	 :accessor :name)
   (content :initarg :content
	    :accessor :content)))

(defun event-server (stream-id)
  (make-instance 'state :name nil :content nil))

(defun event-committer (stream-id decision-name result)
  (pcase result
    (`(!failure ,msg) (error msg))
    (`(!success ,events) (print (format "[DECIDED][%s][%s]: %s" decision-name stream-id events)))))

(defmacro defdecision (decision-name stream-id-command &rest body)
  (declare (indent defun))
  `(let ((stream-id ,(car stream-id-command))
	 (state ,(event-server (car stream-id-command)))
	 (command ,(cadr stream-id-command)))
     (event-committer stream-id ',decision-name ,@body)))

(defmacro defstruct (&rest args)
  `(cl-defstruct ,@args))

(defstruct issue-order order-id annotation)

(defdecision attempt-to-issue-order ("billing-00001" (make-issue-order :order-id 217313 :annotation "pizza margherita"))
  (progn
    (print (:name state))
    (print (issue-order-annotation command))
    `(!success ((make-instance 'event
			       :name 'order-issued
			       :content '((:order-id . ,(issue-order-order-id command))
					  (:annotation . ,(issue-order-annotation command))))))))

(provide 'event)
