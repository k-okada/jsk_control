;;
;; library to evaluate IK quality like reachability
;;


(defclass ik-grid-cell
  :super propertied-object
  :slots (center-pos indices value time-value dimension))

(defmethod ik-grid-cell
  (:init (acenter-pos aindices adimension)
    (setq center-pos acenter-pos)
    (setq indices aindices)
    (setq dimension adimension))
  (:center-pos () center-pos)
  (:indices () indices)
  (:set-value (v) (setq value v))
  (:set-time-value (v) (setq time-value v))
  (:get-value () value)
  (:get-time-value () time-value)
  (:cube (&optional (max-value 1.0))
    "instantiate cube for this cell"
    (let ((c (make-cube dimension dimension dimension)))
      (send c :locate center-pos :world)
      ;;(setf (get c :face-color) :green)
      (setf (get c :face-color)
            (scale (/ 1.0 255.0)
                   (coerce (his2rgb (* 180 (/ value max-value)) 1.0 0.8)
                           float-vector)))
      (gl::transparent c 0.5)
      c))
  (:face (&optional (max-value 1.0))
    (let* ((d/2 (/ dimension 2.0))
           (-d/2 (- d/2))
           (vertices (list
                      (v+ center-pos (float-vector d/2 d/2 0))
                      (v+ center-pos (float-vector -d/2 d/2 0))
                      (v+ center-pos (float-vector -d/2 -d/2 0))
                      (v+ center-pos (float-vector d/2 -d/2 0)))))
      (let ((f (instance face :init :vertices vertices)))
        (let ((fs (instance faceset :init :faces (list f))))
          (setf (get fs :face-color)
                (scale (/ 1.0 255.0)
                       (coerce
                        (his2rgb (* 180 (/ value max-value)) 1.0 0.8)
                        float-vector)))
          (gl::transparent fs 0.5)
          fs))))
  (:clone ()
    (let ((new (instance ik-grid-cell :init center-pos indices dimension)))
      new))
  (:sphere ()
    (let ((s (make-sphere (/ dimension 2.0))))
      (send s :locate center-pos :world)
      s)
    )
  )

(defclass ik-grid
  :super propertied-object
  :slots (min-x max-x min-y max-y min-z max-z grid-step cells
                numx numy numz))

(defmethod ik-grid
  (:init (min-max-x min-max-y min-max-z &key ((:grid-step agrid-step) 100))
    (setq min-x (car min-max-x))
    (setq max-x (cdr min-max-x))
    (setq min-y (car min-max-y))
    (setq max-y (cdr min-max-y))
    (setq min-z (car min-max-z))
    (setq max-z (cdr min-max-z))
    (setq grid-step agrid-step)
    (setq numx (ceiling (/ (- max-x min-x) grid-step)))
    (setq numy (ceiling (/ (- max-y min-y) grid-step)))
    (setq numz (ceiling (/ (- max-z min-z) grid-step)))
    (send self :initialize-cells)
    )
  (:initialize-cells ()
    ;; TODO: using `loop' is better implementation
    (dotimes (i numx)
      (dotimes (j numy)
        (dotimes (k numz)
          (let ((x (+ (* (+ 0.5 i) grid-step) min-x))
                (y (+ (* (+ 0.5 j) grid-step) min-y))
                (z (+ (* (+ 0.5 k) grid-step) min-z)))
            (let ((cell (instance ik-grid-cell :init
                                  (float-vector x y z)
                                  (list i j k)
                                  grid-step)))
              (setq cells (append cells (list cell)))
              ))))))
  (:cells () cells)
  (:valid-cells () (remove-if #'(lambda (x) (= (send x :get-value) 0)) cells))
  (:dump-to-csv (fname)
    (with-open-file (f fname :direction :output)
      (format f "x,y,z,i,j,k,value~%")
      (dolist (cell cells)
        (format f "~A,~A,~A,~A,~A,~A,~A~%"
                (elt (send cell :center-pos) 0)
                (elt (send cell :center-pos) 1)
                (elt (send cell :center-pos) 2)
                (elt (send cell :indices) 0)
                (elt (send cell :indices) 1)
                (elt (send cell :indices) 2)
                (send cell :get-value))
        )
      )
    )
  (:normalize-cells ()
    (let ((sum (reduce #'+ (send-all cells :get-value))))
      (dolist (cell cells)
        (send cell :set-value (/ (send cell :get-value) (float sum))))
      ))
  (:get-cell (indices)
    (let ((i (car indices))
          (j (cadr indices))
          (k (caddr indices)))
      (let ((index (+ k (* j numz) (* i numz numy))))
        (if (and (> index 0) (< index (length cells)))
            (elt cells index)
          nil))))
  (:max-value ()
    (apply #'max (send-all cells :get-value))
    )
  (:sum-filter ()
    ;; Update destructively
    (let ((new-cells nil))
      (dolist (cell cells)
        (if (not (= (send cell :get-value) 0))
            (let* ((cell-indices  (send cell :indices))
                   (i (car cell-indices))
                   (j (cadr cell-indices))
                   (k (caddr cell-indices))
                   (sum 0))
              (let ((neighbors (list (list (1+ i) j k)
                                     (list i j k)
                                     (list (1- i) j k)
                                     (list i (1+ j) k)
                                     (list i (1- j) k)
                                     (list i j (1+ k))
                                     (list i j (1- k)))))
                (dolist (neighbor-index neighbors)
                  (let ((neigbor-cell (send self :get-cell neighbor-index)))
                    (if neigbor-cell
                        (setq sum (+ sum (send neigbor-cell :get-value)))))))
              ;;(send cell :set-value sum)
              (let ((new-cell (send cell :clone)))
                (send new-cell :set-value sum)
                (setq new-cells (append new-cells (list new-cell))))
              )
          (setq new-cells (append new-cells (list cell)))
          ))
      (setq cells new-cells)
      (send self :normalize-cells)
      t))
  (:visualize-objects ()
    ;; Slice in z
    (let ((faces nil)
          (max-value (send self :max-value)))
      (dotimes (k numz)
        (dotimes (i numx)
          (dotimes (j numy)
            (let ((c (send self :get-cell (list i j k))))
              (if (and c (> (send c :get-value) 0.0))
                  (let ((f (send (send self :get-cell (list i j k)) :face max-value)))
                    (setq faces (append faces (list f)))
                    )))))
          )
      (append (send self :max-cells-per-z-lines) faces)))
  (:max-cell ()
    (let ((max-value 0)
          (max-cell nil))
      (dolist (cell cells)              ;linear search
        (when (> (send cell :get-value) max-value)
          (setq max-value (send cell :get-value))
          (setq max-cell cell))
        )
      max-cell))
  (:max-cells-per-z ()
    (let ((cells nil))
      (dotimes (k numz)
        (let ((c (send self :max-cell-in-z-plane k)))
          (if c
              (setq cells (append cells (list c)))))
        )
      cells))
  (:max-cell-in-z-plane (k)
    (let ((max-value 0)
          (max-cell nil))
      (dotimes (i numx)
        (dotimes (j numy)
          (let ((c (send self :get-cell (list i j k))))
            (when (and c (> (send c :get-value) max-value))
              (setq max-value (send c :get-value))
              (setq max-cell c))
            )))
      max-cell))
  (:max-cells-per-z-lines ()
    (let ((lines nil))
      (let ((cells (send self :max-cells-per-z)))
        (dotimes (i (1- (length cells)))
          (push (instance line :init
                          :pvertex (send (elt cells i) :center-pos)
                          :nvertex (send (elt cells (1+ i)) :center-pos))
                lines))
        lines)))
  (:dump-to-file (fname)
    (dump-object fname self))
  (:pos-to-indices (pos)
    (list (floor (/ (- (elt pos 0) min-x) grid-step))
          (floor (/ (- (elt pos 1) min-y) grid-step))
          (floor (/ (- (elt pos 2) min-z) grid-step)))
    )
  (:lookup-stand-location (cset
                           &key
                           (theta-range (deg2rad 90))
                           (theta-num 10)
                           (x-range 1000)
                           (y-range 1000)
                           (x-num 10)
                           (y-num 10))
    "compute transform of cset to maximize cell value"
    ;; x-y-theta
    (let ((midpoint (send cset :midpoint)))
      (let ((z-index (caddr (send self :pos-to-indices))))
        (let ((initial-transform (make-coords :post (send (send self :max-cell-in-z-plane z-index) :center-pos))))
          
          )))
    )
  )

(defun load-ik-grid-from-file (fname)
  (with-open-file (f fname)
    (read f)))

(defclass coordinates-set
  :super propertied-object
  :slots (coordinates-list))

(defmethod coordinates-set
  (:init (initial-set)
    (setq coordinates-list initial-set))
  (:add (c)
    (setq coordinates-list (append coordinates-list (list c))))
  (:transform-copy (c)
    (instance coordinates-set (send-all (send-all coordinates-list :copy-worldcoords) :transrofm c)))
  (:coordinate ()
    coordinates-list)
  (:midpoint ()
    (scale (/ 1.0 (length coordinates-list)) (reduce #'v+ (send-all coordinates-list :worldpos))))
  )

(defun ik-evaluation (robot grid limb ik-args
                      &key
                      (update-view nil)
                      (rotation (unit-matrix)))
  (send robot :fix-leg-to-coords (make-coords))
  (let ((counter 0))
  (dolist (cell (send grid :cells))
    (send robot :reset-pose)
    (if (send* robot limb :inverse-kinematics
               (make-coords :pos (send cell :center-pos)
                            :rot rotation)
               :dump-command nil
               :warnp nil
               ik-args)
        (send cell :set-value 1)
      (send cell :set-value 0))
    (when update-view
      (if (= (send cell :get-value) 1)
          (objects (send cell :cube)))
      (send *irtviewer* :draw-objects)
      (x::window-main-one))
    (incf counter)
    (when (= (mod counter 10) 0)
      (format t "~c~0,4d/~A" #x0d counter (length (send grid :cells)))
      (let* ((percentage (/ (* 100 counter) (length (send grid :cells))))
             (max-bar-length 60)
             (bar-num (/ (* max-bar-length percentage) 100)))
        (dotimes (i bar-num)
          (format t "=")))
      (finish-output))
    )
  (send grid :normalize-cells)
  ))

(defun save-4-views (file-prefix)
    ;; slant
  (send *irtviewer* :viewpoint (float-vector 5000 5000 5000))
  (send *irtviewer* :look1 (float-vector 0 0 800) 30 30)
  (send *irtviewer* :draw-objects)
  (send *irtviewer* :viewer :viewsurface :write-to-image-file (format nil "~A-slant.png" file-prefix))
  ;; up
  (send *irtviewer* :viewpoint (float-vector 0 0 10000))
  (send *irtviewer* :look1 (float-vector 0 0 800) 180 90)
  (send *irtviewer* :draw-objects)
  (send *irtviewer* :viewer :viewsurface :write-to-image-file (format nil "~A-up.png" file-prefix))
  ;; side
  (send *irtviewer* :viewpoint (float-vector 0 10000 0))
  (send *irtviewer* :look1 (float-vector 0 0 800) 90 0)
  (send *irtviewer* :draw-objects)
  (send *irtviewer* :viewer :viewsurface :write-to-image-file (format nil "~A-side.png" file-prefix))

  ;; front
  (send *irtviewer* :viewpoint (float-vector 10000 0 0))
  (send *irtviewer* :look1 (float-vector 0 0 800) 0 0)
  (send *irtviewer* :draw-objects)
  (send *irtviewer* :viewer :viewsurface :write-to-image-file (format nil "~A-front.png" file-prefix))
 )

(defun generate-ik-grid-for-robot (robot file-prefix min-max-x min-max-y min-max-z grid-step
                                         ik-arg
                                         rot-matrix
                                         output-directory)
  (format t "Generate reachability map for ~A with rotation ~A~%" (send robot :name) rot-matrix)
  (setq *grid* (instance ik-grid :init
                         min-max-x min-max-y min-max-z
                         :grid-step grid-step))
  (ik-evaluation *robot* *grid* :larm ik-arg :update-view nil
                 :rotation rot-matrix)
  (send *grid* :dump-to-csv (format nil "~A/~A-input.csv" output-directory file-prefix))
  (send *grid* :dump-to-file (format nil "~A/~A-input.l" output-directory file-prefix))
  (progn (objects (append (send *grid* :visualize-objects)
                          (list *robot*)))
         t)
  (save-4-views (format nil "~A/~A-input" output-directory file-prefix))
  (dotimes (i 10)
    (send *grid* :sum-filter)
    (progn (objects (append (send *grid* :visualize-objects)
                            (list *robot*)))
           t)
    (save-4-views (format nil "~A/~A-iterate~0,3d" output-directory file-prefix i))
    (send *grid* :dump-to-csv (format nil "~A/~A-iterate~0,3d.csv" output-directory file-prefix i))
    (send *grid* :dump-to-file (format nil "~A/~A-iterate~0,3d.l" output-directory file-prefix i))
    )
  )

(defun test-with-jaxon-yup ()
  (require "package://hrpsys_ros_bridge_tutorials/euslisp/jaxon-interface.l")
  (setq *robot* (make-robot-model-from-name "jaxon"))
  (objects (list *robot*))
  (setq *grid* (instance ik-grid :init
                         '(0.0 . 1000.0) '(-1000.0 . 2000.0) '(800.0 . 2000.0)
                         :grid-step 100))
  (format t "Start test~%")
  (ik-evaluation *robot* *grid* :larm '(:rotation-axis :z) :update-view t
                 :rotation (send (make-coords :rpy (list 0 0 pi/2)) :worldrot))
  ;;(send *grid* :normalize-cells)
  (objects (append (send-all (send *grid* :valid-cells) :cube (send *grid* :max-value)) (list *robot*)))
  (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file "input.png")
  t)


(defun test-with-hrp2jsknt-yup ()
  (require "package://hrpsys_ros_bridge_tutorials/euslisp/hrp2jsknt-interface.l")
  (setq *robot* (make-robot-model-from-name "hrp2jsknt"))
  (objects (list *robot*))
  (setq *grid* (instance ik-grid :init
                         '(0.0 . 700.0) '(-1000.0 . 2000.0) '(800.0 . 2000.0)
                         :grid-step 100))
  (format t "Start test~%")
  (ik-evaluation *robot* *grid* :larm '(:rotation-axis :z) :update-view t
                 :rotation (send (make-coords :rpy (list 0 0 pi/2)) :worldrot))
  ;;(send *grid* :normalize-cells)
  (objects (append (send-all (send *grid* :valid-cells) :cube (send *grid* :max-value)) (list *robot*)))
  (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file "input.png")
  t)

(defun test-with-hrp2jsknt-zup ()
  (require "package://hrpsys_ros_bridge_tutorials/euslisp/hrp2jsknt-interface.l")
  (setq *robot* (make-robot-model-from-name "hrp2jsknt"))
  (objects (list *robot*))
  (setq *grid* (instance ik-grid :init
                         '(0.0 . 700.0) '(-1000.0 . 2000.0) '(800.0 . 2000.0)
                         :grid-step 100))
  (format t "Start test~%")
  (ik-evaluation *robot* *grid* :larm '(:rotation-axis :z) :update-view t)
  ;;(send *grid* :normalize-cells)
  (objects (append (send-all (send *grid* :valid-cells) :cube (send *grid* :max-value)) (list *robot*)))
  (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file "input.png")
  t)

(defun test-with-jaxon-zup ()
  (require "package://hrpsys_ros_bridge_tutorials/euslisp/jaxon-interface.l")
  (setq *robot* (make-robot-model-from-name "jaxon"))
  (objects (list *robot*))
  (setq *grid* (instance ik-grid :init
                         '(0.0 . 1000.0) '(-1000.0 . 2000.0) '(800.0 . 2000.0)
                         :grid-step 100))
  (format t "Start test~%")
  (ik-evaluation *robot* *grid* :larm '(:rotation-axis :z) :update-view t)
  ;;(send *grid* :normalize-cells)
  (objects (append (send-all (send *grid* :valid-cells) :cube (send *grid* :max-value)) (list *robot*)))
  (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file "input.png")
  t)

(defun test-with-jaxon-xup ()
  (require "package://hrpsys_ros_bridge_tutorials/euslisp/jaxon-interface.l")
  (setq *robot* (make-robot-model-from-name "jaxon"))
  (objects (list *robot*))
  (setq *grid* (instance ik-grid :init
                         '(0.0 . 1000.0) '(-1000.0 . 2000.0) '(800.0 . 2000.0)
                         :grid-step 100))
  (format t "Start test~%")
  (ik-evaluation *robot* *grid* :larm '(:rotation-axis :z) :update-view t
                 :rotation (send (make-coords :rpy (list 0 -pi/2 0)) :worldrot))
  ;;(send *grid* :normalize-cells)
  (objects (append (send-all (send *grid* :valid-cells) :cube (send *grid* :max-value)) (list *robot*)))
  (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file "input.png")
  t)


(defun test-with-pr2-zup ()
  (require "package://pr2eus/pr2.l")
  (setq *robot* (make-robot-model-from-name "pr2"))
  (objects (list *robot*))
  (setq *grid* (instance ik-grid :init
                         '(0.0 . 1000.0) '(-1000.0 . 2000.0) '(000.0 . 1500.0)
                         :grid-step 100))
  (format t "Start test~%")
  (ik-evaluation *robot* *grid* :larm '(:rotation-axis :z) :update-view t)
  ;;(send *grid* :normalize-cells)
  (objects (append (send-all (send *grid* :valid-cells) :cube (send *grid* :max-value))
                   (list *robot*)))
  (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file "input.png")
  t)


(defun iterate-and-save-images ()
  (dotimes (i 10)
    (send *grid* :sum-filter)
    (progn (objects (append (send *grid* :visualize-objects)
                            (list *robot*)))
           t)
    (send (send (send *irtviewer* :viewer) :viewsurface)
          :write-to-image-file (format nil "iterate~0,3d.png" i))
    (send *grid* :dump-to-csv (format nil "iterate~0,3d.csv" i))
    ))

(defun test-pos-to-index ()
  (dolist (cell (send *grid* :cells))
    (assert (equal (send *grid* :pos-to-indices (send cell :center-pos))
                   (send cell :indices)))
    ))

;; (load "ik-evaluation.l")
;; (progn (test-with-hrp2jsknt-zup) (iterate-and-save-images))
;; (progn (test-with-hrp2jsknt-yup) (iterate-and-save-images))
;; (progn (test-with-jaxon-yup) (iterate-and-save-images))
;; (progn (test-with-jaxon-zup) (iterate-and-save-images))
;; (progn (test-with-jaxon-xup) (iterate-and-save-images))
;; (progn (test-with-pr2-zup) (iterate-and-save-images))
;; (progn     (send *grid* :sum-filter) (objects (append (send *grid* :visualize-objects) (list *robot*))) t)

