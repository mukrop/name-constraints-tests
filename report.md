# Summary

We compared the behaviour of GnuTLS, NSS and OpenSSL with respect to X.509 name constraints extension (in particular DNS, email and IP constraints). 107 of GnuTLS internal tests were transformed to independent cert chains (easy for high-level valid/invalid tests abstracting the library internals). Test details and scripts available at https://gitlab.com/mukrop/name-constraints-tests, feel free to use and improve.

Test results in summary:
* If DNS name constraints are present but the subject alternative names extension is not, GnuTLS checks the common name with regard to DNS name constraints (depending on the key purpose). NSS and OpenSSL do not check common name in this situation.
* Libraries differ in checking the mailbox format: OpenSSL seems to check the format precisely, NSS only partly and GnuTLS not at all.
* OpenSSL does not support IP constraining, thus all corresponding tests containing IP constraints report certificates as INvalid(unsupported name constraint type, name constraints extension is marked critical).

# Details

Below are the details for all failed tests, referencing the test results at https://gitlab.com/mukrop/name-constraints-tests/blob/master/results.txt

## Inspecting common name (test bad3)

The intermediate CA excludes DNS of 'example.com', the endpoint certificate is for common name `www.example.com` but lacks the subject alternative name extension. This tests the legacy processing of X.509 v1 certificates that did not support subject alternative names (tests whether CN is also checked for name constraints).

GnuTLS checks common name compliance to DNS constraints in this case, because 1) there are DNS constraints present 2) there are no subject anternative DNS names and 3) the key purpose is TLS WWW server (More precisely, the key purpose is not set in the test, which is interpreted by GnuTLS as any purpose including the TLS server). This is why the test fails in GnuTLS. In source code, refer to `gnutls_x509_name_constraints_check_crt` in `lib/x509/name_constraints.c`

Neither NSS nor OpenSSL seem to perform such check here, thus the test passes. For NSS, this is contrary to implications of [bug 552346](https://bugzilla.mozilla.org/show_bug.cgi?id=552346) which claims NSS still honors DNS names found in subject CN.

RFC 6125, section 6.4.4 states that "...if and only if the presented identifiers do not include a DNS-ID, SRV-ID, URI-ID, or any application-specific identifier types supported by the client, then the client MAY as a last resort check for a string whose form matches that of a fully qualified DNS domain name in a Common Name field of the subject field (i.e., a CN-ID)." Although this applies to checking the identity of the server (not explicitly the name constraints rules) it makes sense to extend the checks to name constraints rules in such cases.

Furthermore, according to [bug 895063](https://bugzilla.mozilla.org/show_bug.cgi?id=895063), NSS does not constrain IPs in common names when no subject alternative name is present. This was, however, not tested by the provided test suite.

**Security repercussion:** Since certificates with DNS name in CN are still used, one could potentially abuse not constraining the common name by issuing a "valid" certificate by a constrained institutional authority for a third party domain.

**Recommended action:** Inspect whether NSS checks for DNS constraint compliance in common name -- either add a new test case for this or close [bug 552346](https://bugzilla.mozilla.org/show_bug.cgi?id=552346).

## Checking email format (tests suite0-email1a, suite0-email3a)

RFC5280 states that if the endpoint certificate has a subject alternative name of type `rfc822Name` (email), it has to be of the form of a mailbox as specified in Section 4.1.2 of RFC2821 (which is basically `local-part@domain` with some further restrictions on dots, quotes and IP addresses). OpenSSL seems to check emails for the correct form, while NSS does this only partially and GnuTLS not at all.

For suite0-email1a, the intermediate CA permits any mailbox on the host `ccc.com` but not on any of its subdomains. The endpoint certificate claims an alternative email name of 'ccc.com'. This is considered OK by GnuTLS but not by NSS nor OpenSSL.

For suite0-email3a, the intermediate CA permits any mailbox on any subdomains of `ccc.com` but not on the host of `ccc.com`. The endpoint certificate claims an alternative email name of 'xxx.ccc.com'. This is considered OK by GnuTLS and NSS but not OpenSSL. Both abovementioned suites pass in all libraries, if the endpoint email address is prepended with `mail@`.

**Security repercussion:** Althouh NSS and OpenSSL accept certificates invalid according to the RFCs (wrong email format), I do not see a direct security thread this may pose. Furthermore, it is highly unlikely that a trusted CA would issue certificates with such incomplete email addresses.

**Recommended action:** None.

## IP constraints in OpenSSL (tests good2, suite3-ip1, suite3-ip4, suite4-ip1, suite6-ip1, suite7-ip1, suite7-ip3, suite7-ip7, suite8-ip3)

OpenSSL fails on chains that should pass as it does not support IP constraints ('unsupported name constraint type') and the name constraints extension is marked critical.

**Security repercussion:** None, since OpenSSL correctly handles unknown type in critical extension by refusing to validate the certificate.

**Recommended action:** None. (Well, ideally add support for IP constraints.)
