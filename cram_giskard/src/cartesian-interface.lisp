;;;
;;; Copyright (c) 2016, Gayane Kazhoyan <kazhoyan@cs.uni-bremen.de>
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

(in-package :giskard)

(defparameter *giskard-convergence-delta-xy* 0.1 ;; 0.005
  "in meters")
(defparameter *giskard-convergence-delta-theta* 0.5 ;; 0.1
  "in radiants, about 6 degrees")

(defun make-giskard-cartesian-action-goal (left-pose right-pose
                                           pose-base-frame
                                           left-tool-frame right-tool-frame
                                           collision-mode
                                           &key
                                             collision-object-b
                                             collision-object-b-link
                                             collision-object-a
                                             prefer-base align-planes-left align-planes-right)
  (declare (type (or null cl-transforms-stamped:pose-stamped) left-pose right-pose)
           (type (or null string) pose-base-frame left-tool-frame right-tool-frame)
           (type boolean prefer-base align-planes-left align-planes-right))
  (roslisp:make-message
   'giskard_msgs-msg:MoveGoal
   :type (roslisp:symbol-code 'giskard_msgs-msg:MoveGoal ;; :plan_only
                              :plan_and_execute)
   :cmd_seq (vector
             (roslisp:make-message
              'giskard_msgs-msg:movecmd
              :constraints
              (make-constraints-vector
               (make-avoid-joint-limits-constraint)
               (when prefer-base (make-prefer-base-constraint))
               ;; (when align-planes-left
               ;;   (make-align-planes-constraint
               ;;    cram-tf:*robot-base-frame*
               ;;    "refills_finger"
               ;;    (cl-transforms-stamped:make-vector-stamped
               ;;     cram-tf:*robot-base-frame* 0.0
               ;;     (cl-transforms:make-3d-vector 0 0 1))
               ;;    (cl-transforms-stamped:make-vector-stamped
               ;;     cram-tf:*robot-base-frame* 0.0
               ;;     (cl-transforms:make-3d-vector 0 0 1))))
               ;; (when align-planes-right
               ;;   (make-align-planes-constraint
               ;;    cram-tf:*robot-base-frame*
               ;;    "refills_finger"
               ;;    (cl-transforms-stamped:make-vector-stamped
               ;;     cram-tf:*robot-base-frame* 0.0
               ;;     (cl-transforms:make-3d-vector 0 0 1))
               ;;    (cl-transforms-stamped:make-vector-stamped
               ;;     cram-tf:*robot-base-frame* 0.0
               ;;     (cl-transforms:make-3d-vector 0 0 1))))
               )
              :cartesian_constraints
              (make-constraints-vector
               (when left-pose
                 (make-simple-cartesian-constraint
                  pose-base-frame
                  left-tool-frame
                  left-pose))
               (when right-pose
                 (make-simple-cartesian-constraint
                  pose-base-frame
                  right-tool-frame
                  right-pose)))
              :collisions
              (case collision-mode
                (:allow-all (vector (make-allow-all-collision)))
                (:avoid-all (vector (make-avoid-all-collision 0.1)))
                (:allow-hand (vector (make-avoid-all-collision 0.05)
                                     (make-allow-hand-collision
                                      (append (when left-pose '(:left))
                                              (when right-pose '(:right)))
                                      collision-object-b
                                      collision-object-b-link)
                                     (make-allow-hand-collision
                                      (append (when left-pose '(:left))
                                              (when right-pose '(:right)))
                                      (rob-int:get-environment-name))))
                (:allow-attached
                 (vector
                  (roslisp:make-message
                   'giskard_msgs-msg:collisionentry
                   :type (roslisp:symbol-code
                          'giskard_msgs-msg:collisionentry
                          :avoid_all_collisions)
                   :min_dist 0.02)
                  (roslisp:make-message
                   'giskard_msgs-msg:collisionentry
                   :type (roslisp:symbol-code
                          'giskard_msgs-msg:collisionentry
                          :allow_collision)
                   :robot_links (if collision-object-a
                                    (vector (roslisp-utilities:rosify-underscores-lisp-name
                                             collision-object-a))
                                    (vector (roslisp:symbol-code
                                             'giskard_msgs-msg:collisionentry
                                             :all))) ; collision-object-a = attached-obj
                   :body_b (roslisp-utilities:rosify-underscores-lisp-name
                            ;; collision-object-b-link
                            (rob-int:get-environment-name))
                   :link_bs (if collision-object-b-link
                                (vector (roslisp-utilities:rosify-underscores-lisp-name
                                         collision-object-b-link))
                                (vector (roslisp:symbol-code
                                         'giskard_msgs-msg:collisionentry
                                         :all))))))
                (t
                 (vector (roslisp:make-message
                          'giskard_msgs-msg:collisionentry
                          :type (roslisp:symbol-code
                                 'giskard_msgs-msg:collisionentry
                                 :avoid_all_collisions)
                          :min_dist 0.1))))))))

(defun ensure-giskard-cartesian-input-parameters (frame left-pose right-pose)
  (values (when left-pose
            (cram-tf:ensure-pose-in-frame left-pose frame))
          (when right-pose
            (cram-tf:ensure-pose-in-frame right-pose frame))))

(defun ensure-giskard-cartesian-goal-reached (result status goal-position-left goal-position-right
                                              goal-frame-left goal-frame-right
                                              convergence-delta-xy convergence-delta-theta)
  (when (eql status :preempted)
    (roslisp:ros-warn (low-level giskard) "Giskard action preempted with result ~a" result)
    (return-from ensure-giskard-cartesian-goal-reached))
  (when (eql status :timeout)
    (roslisp:ros-warn (pr2-ll giskard-cart) "Giskard action timed out."))
  (when (eql status :aborted)
    (roslisp:ros-warn (pr2-ll giskard-cart) "Giskard action aborted! With result ~a" result)
    ;; (cpl:fail 'common-fail:manipulation-goal-not-reached
    ;;           :description "Giskard did not converge to goal because of collision")
    )
  (when goal-position-left
    (unless (cram-tf:tf-frame-converged goal-frame-left goal-position-left
                                        convergence-delta-xy convergence-delta-theta)
      (cpl:fail 'common-fail:manipulation-goal-not-reached
                :description (format nil "Giskard did not converge to goal:
~a should have been at ~a with delta-xy of ~a and delta-angle of ~a."
                                     goal-frame-left goal-position-left
                                     convergence-delta-xy convergence-delta-theta))))
  (when goal-position-right
    (unless (cram-tf:tf-frame-converged goal-frame-right goal-position-right
                                        convergence-delta-xy convergence-delta-theta)
      (cpl:fail 'common-fail:manipulation-goal-not-reached
                :description (format nil "Giskard did not converge to goal:
~a should have been at ~a with delta-xy of ~a and delta-angle of ~a."
                                     goal-frame-right goal-position-right
                                     convergence-delta-xy convergence-delta-theta)))))

(defun call-giskard-cartesian-action (&key
                                        goal-pose-left goal-pose-right action-timeout
                                        collision-mode collision-object-b collision-object-b-link
                                        collision-object-a
                                        move-base prefer-base align-planes-left align-planes-right
                                        pose-base-frame
                                        (left-tool-frame cram-tf:*robot-left-tool-frame*)
                                        (right-tool-frame cram-tf:*robot-right-tool-frame*)
                                        (convergence-delta-xy *giskard-convergence-delta-xy*)
                                        (convergence-delta-theta *giskard-convergence-delta-theta*))
  (declare (type (or null cl-transforms-stamped:pose-stamped) goal-pose-left goal-pose-right)
           (type (or null number) action-timeout convergence-delta-xy convergence-delta-theta)
           (type (or null string) pose-base-frame left-tool-frame right-tool-frame)
           (type boolean move-base prefer-base align-planes-left align-planes-right))

  (when prefer-base
    (setf move-base T))
  (if (and move-base (not pose-base-frame))
      (setf pose-base-frame cram-tf:*odom-frame*)
      (setf pose-base-frame cram-tf:*robot-base-frame*))

  (if (or goal-pose-left goal-pose-right)
      (multiple-value-bind (goal-pose-left goal-pose-right)
          (ensure-giskard-cartesian-input-parameters pose-base-frame goal-pose-left goal-pose-right)

        (cram-tf:visualize-marker (list goal-pose-left goal-pose-right) :r-g-b-list '(1 0 1))
        (multiple-value-bind (result status)
            (let ((goal (make-giskard-cartesian-action-goal
                         goal-pose-left goal-pose-right
                         pose-base-frame left-tool-frame right-tool-frame
                         collision-mode
                         :collision-object-b collision-object-b
                         :collision-object-b-link collision-object-b-link
                         :collision-object-a collision-object-a
                         :prefer-base prefer-base
                         :align-planes-left align-planes-left
                         :align-planes-right align-planes-right)))
              (actionlib-client:call-simple-action-client
               'giskard-action
               :action-goal goal
               :action-timeout action-timeout))

          (ensure-giskard-cartesian-goal-reached
           result status goal-pose-left goal-pose-right
           left-tool-frame right-tool-frame
           convergence-delta-xy convergence-delta-theta)
          (values result status)
          ;; return the joint state, which is our observation
          (joints:full-joint-states-as-hash-table)))
      ;; return NIL as observation if the goal is empty
      (and (roslisp:ros-info (pr2-ll giskard-cart) "Got an empty goal...")
           NIL)))
