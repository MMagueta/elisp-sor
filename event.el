(require 'pg)

(defun transact (category object-id event)
  (let ((*pg* (pg-connect "message_store" "admin" "admin" "localhost" 5432))
	(content (encode-hex-string "abc")))
    (pg-result (pg-exec-prepared *pg* "call message_store.transact($1, $2, $3, $4)" `((,category . "text")
										 (,object-id . "text")
										 (,(symbol-name (name-of event)) . "text")
										 (,(encode-hex-string (prin1-to-string event)) . "bytea"))) :tuple 0)))

(defun hydrate (category object-id)
  (let* ((*pg* (pg-connect "message_store" "admin" "admin" "localhost" 5432))
	(statement (pg-exec-prepared *pg* "select data from message_store.messages where category = $1 and object_id = $2 order by time"
				     `((,category . "text")
				       (,object-id . "text")))))
    (mapcar (lambda (x) (read (decode-hex-string (cadr x)))) (pg-result statement :tuples))))

(hydrate "pizza" "0001")

(transact "pizza" "0001" (defevent issue-order :order-id 123 :annotation "pizza pepperoni"))
(transact "pizza" "0001" (defevent dispatch-order :order-id 123 :address "Saint James St. No 521"))

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

(defun pair (lst)
  (cl-loop for (key value) on lst by 'cddr
           collect (cons key value)))

(defmacro defevent (name &rest args)
  `'(,name ,(pair args)))

(defun get-attr (attribute event)
  (cdr (seq-find (lambda (x) (equal attribute (car x))) (cadr event))))

(defun name-of (event)
  (car event))

;; (name-of (defevent issue-order :order-id 123 :annotation "pizza pepperoni"))
;; (get-attr :annotation (defevent issue-order :order-id 123 :annotation "pizza pepperoni"))



(defdecision attempt-to-issue-order ("billing-00001" (make-issue-order :order-id 217313 :annotation "pizza margherita"))
  (progn
    (print (:name state))
    (print (issue-order-annotation command))
    `(!success ((make-instance 'event
			       :name 'order-issued
			       :content '((:order-id . ,(issue-order-order-id command))
					  (:annotation . ,(issue-order-annotation command))))))))

(provide 'event)
