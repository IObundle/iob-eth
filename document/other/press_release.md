<!--
SPDX-FileCopyrightText: 2025 IObundle

SPDX-License-Identifier: MIT
-->

# FOR IMMEDIATE RELEASE

## IObundle Releases Industrial-Grade Open-Source Ethernet IP Core with Comprehensive Verification Flow

**Lisbon, Portugal – February 15, 2026** – IObundle, Lda, a leading provider of open-source semiconductor IP cores, today announced the availability of IOb-Eth, a professional-grade, MIT-licensed Ethernet IP core designed for industrial applications. The core represents a significant advancement in open-source hardware IP, offering production-ready functionality with comprehensive verification, synthesis, and FPGA implementation support.

### Modern Verilog Implementation Addresses Legacy Opencores Limitations

IOb-Eth is inspired by the well-known Opencores Ethmac project but has been completely rewritten with modern industrial-grade Verilog code, eliminating the bugs and limitations of the original implementation. The core maintains driver compatibility with the legacy ethmac through a similar Control/Status Register interface, enabling seamless migration for existing users while providing superior reliability and maintainability.

The core implements raw socket Ethernet communication at the data link layer (Layer 2) of the OSI Model, providing essential networking functionality for embedded systems and FPGA-based designs.

### Production-Ready with Proven Track Record

Unlike many open-source IP cores that remain in experimental stages, IOb-Eth has been extensively validated through multiple successful FPGA deployments. The core features:

- **Complete Simulation Infrastructure**: Fully functional simulation environment enabling comprehensive pre-silicon verification
- **Synthesis-Ready Code**: Clean, synthesizable Verilog that meets industry coding standards
- **FPGA-Proven**: Successfully deployed and tested on multiple FPGA platforms in real-world applications
- **Verilator Integration**: Advanced lint checking and simulation coverage flow using industry-standard Verilator tools
- **Quality Assurance**: Rigorous verification methodology ensuring reliability for production use

### Comprehensive Feature Set

IOb-Eth provides a complete solution for Ethernet connectivity in SoC designs:

- Raw socket Ethernet communication (OSI Layer 2)
- AXI memory interface for seamless system integration
- PHY interface supporting standard Ethernet physical layers
- Configurable buffer descriptors for flexible packet management
- Interrupt support for efficient event handling
- Driver-compatible with Linux kernel ethoc driver
- Python-based integration framework for easy SoC adoption
- Bare-metal C driver library with comprehensive API

### Professional Support and Services Available

Recognizing that adopting new IP cores can be challenging, IObundle offers professional services to assist organizations in integrating IOb-Eth into their designs. Support services include:

- Integration assistance for SoC and FPGA projects
- Custom configuration and optimization
- Training and technical consultation
- Design review and verification support

"IOb-Eth represents our commitment to providing the open-source hardware community with professional-quality IP that meets the stringent requirements of industrial applications," said a spokesperson for IObundle. "We've taken the lessons learned from the Opencores Ethmac and created a modern, reliable solution that teams can confidently deploy in production systems."

### Open Source with Permissive Licensing

IOb-Eth is released under the permissive MIT License, allowing unrestricted use in both commercial and non-commercial projects. The complete source code, documentation, and integration examples are available on GitHub.

### Part of NGI-Funded OpenCryptoTester and SoCLinux Initiative

The IOb-Eth core serves as a verification tool for the OpenCryptoTester project, which is funded through the NGI Assure Fund. This initiative, established by NLnet with financial support from the European Commission's Next Generation Internet programme, aims to advance secure and reliable open-source technologies.

### Availability

IOb-Eth is immediately available for download from the IObundle GitHub repository at https://github.com/IObundle/iob-eth. The repository includes complete source code, comprehensive documentation, integration examples, and pre-built FuseSoC-compatible releases.

For more information about IOb-Eth, technical documentation, or professional support services, visit https://github.com/IObundle or contact IObundle, Lda.

### About IObundle

IObundle, Lda is a technology company specializing in commercial and open-source semiconductor IP cores and FPGA solutions. The company is committed to providing high-quality, industrial-grade IP cores that enable developers and organizations to accelerate their hardware development while maintaining the freedom and flexibility of open-source licensing.

### Media Contact

For press inquiries, please visit: https://www.iobundle.com

---

**Technical Specifications:**
- License: MIT
- Interface: AXI memory interface, Standard Ethernet PHY
- Verification: Verilator-based simulation and coverage flow
- Documentation: Comprehensive user guide and API documentation
- Platform Support: Multiple FPGA families, Linux driver compatible
- Integration: Python-based SoC integration framework

###

**Note to Editors:** High-resolution logos, technical diagrams, and additional resources are available upon request. IOb-Eth is part of the broader IOb-SoC ecosystem, which provides a complete framework for building custom System-on-Chip designs.
