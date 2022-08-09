Contributing
############

We welcome contributions from all people as long as they don't include any discriminatory, hateful language, don't force
users to use proprietary technologies and are related to the F4PGA project.

We will prioritize contributions which serve to improve support for platforms that are officially supported by ``f4pga``.
UX-related contributions are welcome as well.

Reporting bugs
==============

If you find a bug and want other to take a look, please open an issue, attach a log and a minimal example for
reproducing the bug.
Use ``-vv`` (maximum verbosity level) option when running ``f4pga`` if possible.

Please, remember to specify the version of architecture definitions you are using (this applies only to VPR-based flows).
If you used a pre-built packages, please provide a hash that identifies the package and name of the platform in question
(*XC7*/*EOS-S3*).
The hash is the last alphanumeric component before the ``.tar.gz`` suffix of the archive with prebuilt packages.
Use your local installation to look-up the hash.
Links to packages in :ref:`examples:Getting` get automatically updated to point to the latest packages.

If you built the architecture definitions yourself, please specify the hash of the commit you've used.

If you don't specify the version of architecture definitions, we might be unable to reproduce the bug.
