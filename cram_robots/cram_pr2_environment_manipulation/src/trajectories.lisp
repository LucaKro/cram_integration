;;;
;;; Copyright (c) 2018, Christopher Pollok <cpollok@uni-bremen.de>
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;;     * Redistributions of source code must retain the above copyright
;;;       notice, this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright
;;;       notice, this list of conditions and the following disclaimer in the
;;;       documentation and/or other materials provided with the distribution.
;;;     * Neither the name of the Institute for Artificial Intelligence/
;;;       Universitaet Bremen nor the names of its contributors may be used to
;;;       endorse or promote products derived from this software without
;;;       specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :pr2-em)

(defparameter *drawer-handle-grasp-x-offset* 0.0 "in meters")
(defparameter *drawer-handle-pregrasp-x-offset* 0.10 "in meters")
(defparameter *drawer-handle-retract-offset* 0.10 "in meters")
(defparameter *door-handle-retract-offset* 0.05 "in meters")

(defmethod man-int:get-object-type-gripper-opening ((object-type (eql :container))) 0.10)
(defmethod man-int:get-object-type-gripper-opening ((object-type (eql :container-prismatic))) 0.10)
(defmethod man-int:get-object-type-gripper-opening ((object-type (eql :container-revolute))) 0.10)

(defun get-container-to-gripper-transform (object-name
                                           arm
                                           btr-environment)
  "Get the transform from the container handle to the robot's gripper."
  (let* ((object-name
           (roslisp-utilities:rosify-underscores-lisp-name object-name))
         (handle-name
           (cl-urdf:name (get-handle-link object-name btr-environment)))
         (handle-tf
           (cl-transforms-stamped:transform->transform-stamped
            cram-tf:*fixed-frame*
            handle-name
            0
            (cl-transforms:pose->transform
             (get-urdf-link-pose handle-name btr-environment))))
         (container-tf
           (cl-transforms-stamped:transform->transform-stamped
            cram-tf:*fixed-frame*
            object-name
            0
            (cl-transforms:pose->transform
             (get-urdf-link-pose object-name btr-environment))))
         (tool-frame
           (ecase arm
             (:left cram-tf:*robot-left-tool-frame*)
             (:right cram-tf:*robot-right-tool-frame*))))
    (cram-tf:multiply-transform-stampeds
     object-name
     tool-frame
     (cram-tf:multiply-transform-stampeds
      object-name
      handle-name
      (cram-tf:transform-stamped-inv container-tf)
      handle-tf)
     (cl-transforms-stamped:make-transform-stamped
      handle-name
      tool-frame
      0.0
      (cl-transforms:make-3d-vector *drawer-handle-grasp-x-offset* 0.0d0 0.0d0)
      (cl-transforms:matrix->quaternion
       #2A((0 0 -1)
           (0 1 0)
           (1 0 0)))))))

(defmethod man-int:get-action-trajectory :before ((action-type (eql :opening))
                                                   arm
                                                   grasp
                                                   objects-acted-on
                                                   &key
                                                     opening-distance)
  "Raise an error if object count is not right."
  (declare (ignore arm grasp opening-distance))
  (when (not (eql 1 (length objects-acted-on)))
    (error (format nil "Action-type ~a requires exactly one object.~%" action-type))))

(defmethod man-int:get-action-trajectory :before ((action-type (eql :closing))
                                                   arm
                                                   grasp
                                                   objects-acted-on
                                                   &key
                                                     opening-distance)
  "Raise an error if object count is not right."
  (declare (ignore arm grasp opening-distance))
  (when (not (eql 1 (length objects-acted-on)))
    (error (format nil "Action-type ~a requires exactly one object.~%" action-type))))

(defun make-trajectory (action-type
                        arm
                        objects-acted-on
                        opening-distance)
  "Make a trajectory for opening or closing a container.
   This should only be used by get-action-trajectory for action-types :opening and
   :closing."
  (when (equal action-type :closing)
    (setf opening-distance (- opening-distance)))
  (let* ((object-designator (car objects-acted-on))
         (object-name
           (desig:desig-prop-value
            object-designator :urdf-name))
         (object-type
           (desig:desig-prop-value
            object-designator :type))
         (object-environment
           (desig:desig-prop-value
            object-designator :part-of))
         (object-transform
           (second
            (get-container-pose-and-transform
             object-name
             object-environment)))
         (grasp-pose
           (get-container-to-gripper-transform
            object-name
            arm
            object-environment)))
    
    (alexandria:switch
        (object-type :test (lambda (?type ?super-type)
                             (prolog:prolog
                              `(man-int:object-type-subtype
                                ,?super-type ,?type))))
      (:container-prismatic
       (make-prismatic-trajectory object-transform arm action-type grasp-pose opening-distance))
      (:container-revolute
       (make-revolute-trajectory object-transform arm action-type grasp-pose opening-distance
                                 object-name object-environment))
      (T (error "Unsupported container-type: ~a." object-type)))))

(defun make-prismatic-trajectory (object-transform arm action-type
                                  grasp-pose opening-distance)
  (mapcar (lambda (label transforms)
                (man-int:make-traj-segment
                 :label label
                 :poses (mapcar (man-int:make-object-to-standard-gripper->base-to-particular-gripper-transformer
                                 object-transform arm)
                                transforms)))
              (list
               :reaching
               :grasping
               action-type
               :retracting)
              (list
               (list (cram-tf:translate-transform-stamped
                      grasp-pose :x-offset *drawer-handle-pregrasp-x-offset*))
               (list grasp-pose)
               
               (list (cram-tf:translate-transform-stamped
                      grasp-pose :x-offset opening-distance))
               
               (list (cram-tf:translate-transform-stamped
                      grasp-pose :x-offset (+ opening-distance *drawer-handle-retract-offset*))))))

(defun make-revolute-trajectory (object-transform arm action-type
                                 grasp-pose opening-angle object-name object-environment)
  (let* ((traj-poses (get-revolute-traj-poses object-name object-environment opening-angle)))
    (mapcar (lambda (label transforms)
              (man-int:make-traj-segment
               :label label
               :poses (mapcar (man-int:make-object-to-standard-gripper->base-to-particular-gripper-transformer
                               object-transform arm)
                              transforms)))
            (list
             :reaching
             :grasping
             action-type
             :retracting)
            (list
             (list (cram-tf:translate-transform-stamped
                    grasp-pose :x-offset *drawer-handle-pregrasp-x-offset*))
             (list grasp-pose)
             
             traj-poses

             (let ((last-traj-pose (car (last traj-poses))))
               (list (cram-tf:apply-transform
                      last-traj-pose
                      (cl-transforms-stamped:make-transform-stamped
                       (cl-transforms-stamped:child-frame-id last-traj-pose)
                       (cl-transforms-stamped:child-frame-id last-traj-pose)
                       (cl-transforms-stamped:stamp last-traj-pose)
                       (cl-transforms:make-3d-vector 0 0 -0.1)
                       (cl-transforms:make-identity-rotation)))))))))

(defun get-revolute-traj-poses (object-name btr-environment opening-angle)
  (setf object-name (roslisp-utilities:rosify-underscores-lisp-name object-name))
  (let* ((handle-name
           (cl-urdf:name (get-handle-link object-name btr-environment)))
         (handle-tf
           (cl-transforms-stamped:transform->transform-stamped
            cram-tf:*fixed-frame*
            handle-name
            0
            (cl-transforms:pose->transform
             (get-urdf-link-pose handle-name btr-environment))))
         (container-tf
           (cl-transforms-stamped:transform->transform-stamped
            cram-tf:*fixed-frame*
            object-name
            0
            (cl-transforms:pose->transform
             (get-urdf-link-pose object-name btr-environment)))))
    (calculate-handle-to-gripper-transforms handle-tf container-tf opening-angle)))

(defun calculate-handle-to-gripper-transforms (map-to-handle map-to-joint
                                               &optional (theta-max
                                                          (cma:degrees->radians 70)))
  (let* ((theta-step (if (>= theta-max 0)
                         0.1
                         -0.1))
         (handle-to-joint
           (cram-tf:apply-transform (cram-tf:transform-stamped-inv map-to-handle)
                                    map-to-joint))
         (joint-to-handle (cram-tf:transform-stamped-inv handle-to-joint)))
    (mapcar (lambda (joint-to-circle-point)
              (cram-tf:apply-transform
               joint-to-handle
               (cram-tf:pose-stamped->transform-stamped
                (cram-tf:rotate-pose
                 (cram-tf:strip-transform-stamped
                  (cram-tf:apply-transform handle-to-joint joint-to-circle-point))
                 :x
                 (cram-math:degrees->radians 0))
                (cl-transforms-stamped:child-frame-id joint-to-circle-point))))
            (loop for theta = 0.0 then (+ theta-step theta)
                  while (< (abs theta) (abs theta-max))
                  collect
                  (let ((rotation
                          (cl-tf:axis-angle->quaternion
                           (cl-transforms:make-3d-vector 0 0 1) theta)))
                    (cl-transforms-stamped:make-transform-stamped
                     (cl-transforms-stamped:frame-id joint-to-handle)
                     cram-tf:*robot-right-tool-frame*
                     (cl-transforms-stamped:stamp joint-to-handle)
                     (cl-transforms:rotate rotation (cl-transforms:translation joint-to-handle))
                     (cl-transforms:euler->quaternion
                      :ax (/ pi 2) ;; bring it into position to grasp vertical handle
                      :az (+ (/ pi -2) theta)) ;; turn it while opening
                     ))))))

(defmethod man-int:get-action-trajectory ((action-type (eql :opening))
                                           arm
                                           grasp
                                           objects-acted-on
                                           &key
                                             opening-distance)
  (make-trajectory action-type arm objects-acted-on opening-distance))

(defmethod man-int:get-action-trajectory ((action-type (eql :closing))
                                           arm
                                           grasp
                                           objects-acted-on
                                           &key
                                             opening-distance)
  (make-trajectory action-type arm objects-acted-on opening-distance))
