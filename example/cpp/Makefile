
CXX=g++
CC=gcc
APP:=basys3_rmii_ethernet
BUILD:=./build
OBJ_DIR:=$(BUILD)/objects
APP_DIR:=$(BUILD)/apps
VERSION?=release
CXXFLAGS:=-std=c++20 -O2 -g -Wall -Wextra -Werror -Wswitch-enum -Wshadow -Woverloaded-virtual -Wnull-dereference -Wformat=2 -Wno-error=unused-variable

INCLUDE:=-I.

SRCS := $(wildcard *.cpp)
OBJECTS:=$(SRCS:%.cpp=$(OBJ_DIR)/%.o)

$(OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(@D)
	@$(CXX) $(CXXFLAGS) $(INCLUDE) -c $< -o $@
	@echo "Compiled: $@"

$(APP_DIR)/$(APP): $(OBJECTS)
	@mkdir -p $(@D)
	@$(CXX) $(CXXFLAGS) $(INCLUDE) -o $@ $^ $(LDLAGS)
	@echo "\033[32mBUILT: $@\033[0m"

build:
	@mkdir -p $(APP_DIR)
	@mkdir -p $(OBJ_DIR)

clean:
	-@rm -rvf $(BUILD)

all: build $(APP_DIR)/$(APP)

.PHONY: build clean all
