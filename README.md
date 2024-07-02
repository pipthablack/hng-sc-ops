# User Management Script

## Overview

This script automates the process of creating users and groups on a macOS system. It reads a specified input file to create users, assign them to groups, create personal groups for each user, and securely store their generated passwords. Additionally, it logs all actions taken during the process.

## Prerequisites

- macOS with `dscl` (Directory Service command-line utility) available
- OpenSSL installed
- Root privileges to execute the script

## Usage

### Input File Format

The input file should be a CSV file with the following format:

Each line represents a user and the groups they should be added to, separated by a semicolon. Groups are separated by commas.

| Username | Groups |
|----------|--------|
| testuser1 | testgroup1,testgroup2 |
| testuser2 | testgroup3,testgroup4 |

### Running the Script

1. **Prepare the environment**:
    - Create the necessary directories and files for logging and password storage:
      

