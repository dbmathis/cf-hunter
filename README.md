
# CF Hunter

Discover tasks or processes in an org that are discreetly using memory / disk space.


## Installation

### Install dependency jq.

#### jq:
https://stedolan.github.io/jq/download


### Install hunter
```
$ git clone https://github.com/dbmathis/cf-hunter.git
$ cd cf-hunter
$ chmod +x cf-hunter.sh
```

## Target CF.
```
$ cf login -a api.<system domain>
```
  
## Usage
```
Usage:
  cf-hunter.sh -o <org> [-s <space>]

  -o|--org       <text> cf org
  -s|--space     <text> cf space
  -h|--help
Examples:
  $ cf-hunter.sh -o system -s autoscaling
```

## Example
```
MacBook-Pro-3 cf-hunter$ ./cf-hunter.sh -o dmathis
Hierarchy                                                    Disk         Memory
================================================================================
Org: dmathis                                              9216 MB        4539 MB
================================================================================
     Space: redis                                         5120 MB        1152 MB
--------------------------------------------------------------------------------
          App: cf-nodejs                                  1024 MB         128 MB
--------------------------------------------------------------------------------
               Process: web                               1024 MB         128 MB
--------------------------------------------------------------------------------
          App: test-app                                   1024 MB         256 MB
--------------------------------------------------------------------------------
               Process: web                               1024 MB         256 MB
--------------------------------------------------------------------------------
          App: redis-example-app                          3072 MB         768 MB
--------------------------------------------------------------------------------
               Task: 4f35e4df                             1024 MB         256 MB
               Task: 9355a23c                             1024 MB         256 MB
               Process: web                               1024 MB         256 MB
================================================================================
     Space: outerspace                                    4096 MB        3387 MB
--------------------------------------------------------------------------------
          App: redis-example-app-2                        4096 MB        3387 MB
--------------------------------------------------------------------------------
               Task: 56554a31                             1024 MB         150 MB
               Task: dcc22b5d                             1024 MB         150 MB
               Task: 70184abc                             1024 MB          15 MB
               Process: web                               1024 MB        3072 MB
================================================================================
     Space: myspace                                          0 MB           0 MB
```

## Maintainer

* [David Mathis](https://github.com/dbmathis)


## Support

This is a community supported cloud foundry tool. Opening issues for questions, feature requests and/or bugs is the best path to getting "support".
