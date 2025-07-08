(require 'pg)

(defvar *pg* (pg-connect "message_store" "admin" "admin" "localhost" 5432))

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

(defun event-server (category object-id)
  (make-instance 'state :name (format "%s:%s" category object-id) :content (hydrate category object-id)))

(defun event-committer (category object-id decision-name result)
  (pcase result
    (`(!failure ,msg) (error msg))
    (`(!success ,events) (progn
			   (print (format "[DECIDED][%s][%s:%s]: %s" decision-name category object-id events))
			   (transact category object-id events)))))

(defmacro decision (decision-name stream-id-command &rest body)
  (declare (indent defun))
  `(let ((category ,(car stream-id-command))
	 (object-id ,(cadr stream-id-command))
	 (state ,(event-server (car stream-id-command)
			       (cadr stream-id-command)))
	 (command ,(caddr stream-id-command)))
     (event-committer category object-id ',decision-name ,@body)))

(defun pair (lst)
  (cl-loop for (key value) on lst by 'cddr
           collect (cons key value)))

(defmacro defevent (name &rest args)
  `'(,name ,(pair args)))

;; remove his car for defevent! it splices
;; defining yourself the list requires it though
(defun get-attr (attribute event)
  (car (cdr (seq-find (lambda (x) (equal attribute (car x))) (cadr event)))))

(defun name-of (event)
  (car event))

;; (name-of (defevent issue-order :order-id 123 :annotation "pizza pepperoni"))
;; (get-attr :annotation (defevent issue-order :order-id 123 :annotation "pizza pepperoni"))
;; (get-attr :annotation '(order ((:order-id 1)
;; 			       (:type "cashier")
;; 			       (:annotation "Pepperoni Pizza")
;; 			       (:payment-amount 10.00)
;; 			       (:currency 'USD))))

(defun transact (category object-id events)
  (let ((encoded-events
	 (mapcar (lambda (e) (concat "\\\\x" (encode-hex-string (prin1-to-string e)))) events))
	(event-names (mapcar (lambda (e) (symbol-name (name-of e))) events)))
    (pg-result (pg-exec-prepared *pg* "call message_store.transact($1, $2, $3::text[], $4::bytea[])"
				 `((,category . "text")
				   (,object-id . "text")
				   (,(concat "{" (mapconcat #'identity event-names ",") "}") . "text[]")
				   (,(concat "{" (mapconcat #'identity encoded-events ",") "}") . "bytea[]"))) :tuple 0)))

(defun hydrate (category object-id)
  (let ((statement (pg-exec-prepared *pg* "select data from message_store.messages where category = $1 and object_id = $2 order by time"
				     `((,category . "text")
				       (,object-id . "text")))))
    (mapcar (lambda (x) (read (car x))) (pg-result statement :tuples))))

(decision attempt-to-issue-order ("billing" "1" '(order ((:order-id 1)
							 (:type "cashier")
							 (:annotation "Pepperoni Pizza")
							 (:payment-amount 10.00)
							 (:currency 'USD))))
  (progn
    ;; Payments via the cashier are automatically payed in cash
    (if (:content state)
	`(!failure "The order already exists.")
      (cond ((string= (get-attr :type command)
		      "cashier")
	     `(!success ,(list (defevent placed-order
					 :order-id 1
					 :annotation (get-attr :annotation command))
			       (defevent payment
					 :order-id 1
					 :currency (get-attr :currency command)
					 :amount (get-attr :payment-amount command)))))
	    ((string= (get-attr :type command)
		      "online")
	     `(!success ,(list (defevent placed-order
					 :order-id 1
					 :annotation (get-attr :annotation command)))))
	    (t `(!failure "Order method not recognized"))))))

(decision delivery ("pizza" "0001" '(dispatch-delivery ((:order-id 217313)
							(:driver "John")
							(:address "Saint James St. No 521"))))
  (progn
    `(!success '((defevent delivery-dispatched
			   :order-id (get-attr :order-id command)
			   :driver (get-attr :driver command)
			   :address (get-atr :address command))))))

(provide 'event)
