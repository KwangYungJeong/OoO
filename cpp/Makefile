# Compiler and flags
CXX = g++
CXXFLAGS = -std=c++17 -Wall -Icore
LDFLAGS =

# Source files
SRCS = sim/sim_rat.cpp core/rat.cpp

# Object files
OBJS = $(SRCS:.cpp=.o)

# Executable name
TARGET = sim_rat

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS)

# Rule to compile source files into object files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)
