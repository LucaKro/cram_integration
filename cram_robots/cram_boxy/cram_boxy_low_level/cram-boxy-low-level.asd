;;; Copyright (c) 2017, Gayane Kazhoyan <kazhoyan@cs.uni-bremen.de>
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
;;;     * Neither the name of the Intelligent Autonomous Systems Group/
;;;       Technische Universitaet Muenchen nor the names of its contributors 
;;;       may be used to endorse or promote products derived from this software 
;;;       without specific prior written permission.
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

(defsystem cram-boxy-low-level
  :author "Gayane Kazhoyan"
  :maintainer "Gayane Kazhoyan"
  :license "BSD"

  :depends-on (roslisp
               actionlib
               roslisp-utilities
               roslisp-msg-protocol ; for ros-message class type
               cram-language ; for with-failure-handling to the least
               cl-transforms-stamped
               cl-transforms
               cram-tf
               cram-common-failures
               ;; for reading out arm joint names
               cram-robot-interfaces
               cram-utilities
               cram-prolog
               cram-boxy-description
               ;; msgs for low-level communication
               geometry_msgs-msg ; for force-torque sensor wrench
               std_srvs-srv ; for zeroing force-torque sensor
               giskard_msgs-msg
               move_base_msgs-msg
               visualization_msgs-msg
               iai_wsg_50_msgs-msg
               sensor_msgs-msg
               iai_control_msgs-msg ; neck message
               wiggle_msgs-msg)
  :components
  ((:module "src"
    :components
    ((:file "package")
     (:file "low-level-common" :depends-on ("package"))
     (:file "simple-actionlib-client" :depends-on ("package"))
     (:file "joint-states" :depends-on ("package"))
     (:file "giskard-joint" :depends-on ("package"
                                         "low-level-common"
                                         "simple-actionlib-client"
                                         "giskard-common"
                                         "joint-states"))
     (:file "giskard-common" :depends-on ("package" "simple-actionlib-client"))
     (:file "giskard-cartesian" :depends-on ("package"
                                             "simple-actionlib-client"
                                             "giskard-common"
                                             "giskard-joint"))
     (:file "nav-pcontroller" :depends-on ("package"
                                           "low-level-common"
                                           "simple-actionlib-client"))
     (:file "neck" :depends-on ("package"))
     (:file "grippers" :depends-on ("package" "joint-states"))
     (:file "force-torque-sensor" :depends-on ("package"))
     (:file "wiggle" :depends-on ("package" "simple-actionlib-client"
                                            "giskard-cartesian" "force-torque-sensor"))))))
