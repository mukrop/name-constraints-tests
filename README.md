X.509 name constraints tests
============================

This repository contains a set of scripts for automatically testing X.509 name constraints implementation in GnuTLS, NSS and OpenSSL. For easy reading, the repository contains also a text file with test results (see details below).

## Test results

* Test results can be found in [results.txt](results.txt).
* Column `Expected` has the expected result, subsequent columns have results for particular libraries.
* These were run on Fedora 23 with OpenSSL 1.0.2h-fips, NSS 3.25.0 and GnuTLS 3.5.4 (commit d69e56, unreleased by the date of testing).
* Test results in summary:
  * OpenSSL seems not to support IP constraining, thus all corresponding tests report `FAIL` (unsupported name constraint type).
  * If DNS name constraints are present but the subject alternative names extension is not, GnuTLS checks the common name with regard to DNS name constraints (depending on the key purpose). NSS and OpenSSL do not check common name in this situation.
  * Libraries differ in checking the mailbox format: OpenSSL seems to check the format precisely, NSS only partly and GnuTLS not at all.

## Testing

* The test suite is in the form of certificate chains that are validated one by one.
* Individual test chains are created on-the-fly by GnuTLS from provided templates.
* The tests reflect the GnuTLS built-in tests from `tests/name-constraints.c`, `tests/name-constraints-merge.c`, `tests/name-cinstraints-ip.c` and a few additional tests.

## Running the test case

* The suite is run by execucing runChainTests.sh bash script.
  * Running with no command line arguments will print the usage and currently set paths for dependencies.
  * Tests are performed by providing a test template as an argument.
  * For running all tests, execute `./runChainTests.sh tests/*/*`
* By default, outputs from individual libraries is suppressed. To enable it (e.g. for debugging purposes), set envidonment variable 'DEBUG' to 1.
* The scripts depends on `certtool` (provided by GnuTLS), `certutil` (provided by NSS) and `openssl` (provided by OpenSSL).
* The script uses system-installed libraries versions by default -- this can be changed in the header of the script.

## Author

The tests were run by Martin Ukrop in September 2016.
