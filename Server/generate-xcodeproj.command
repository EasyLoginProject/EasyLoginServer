#!/bin/bash

cd $(dirname "${BASH_SOURCE[0]}")
swift package generate-xcodeproj --xcconfig-overrides EasyLogin.xcconfig
