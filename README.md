# EasyQSO - Amateur Radio QSO Logger

EasyQSO is an iOS application designed for amateur radio enthusiasts to record, query, and manage their QSO (contact) logs. It provides comprehensive features for logging amateur radio contacts with support for import/export functionality.

## Features

### 1. QSO Recording
- Record callsign, date/time, band, mode, frequency and other basic information
- Record signal reports (RST)
- Add operator name, QTH location and remarks
- Data validation to ensure input accuracy

### 2. Log Query
- View all QSO records
- Search for specific records (by callsign, band, mode, etc.)
- Edit and delete existing records

### 3. Import/Export
- Support for ADIF format export (amateur radio standard format)
- Support for CSV format export (universal format)
- Import from ADIF files
- Import from CSV files

### 4. Advanced Features
- Interactive map location picker
- Timezone management for import/export
- Grid square coordinate support
- Satellite operation logging

## Technical Implementation

- Built with SwiftUI for user interface
- Core Data for data persistence
- MVVM architecture pattern
- Supports iOS 14.0 and above
- Full localization support (English and Chinese)

## Project Structure

- `HamRadioLoggerApp.swift` - Application entry point
- `ContentView.swift` - Main view with tab navigation
- `QSORecordView.swift` - QSO recording view
- `LogQueryView.swift` - Log query view
- `EditQSOView.swift` - QSO record editing view
- `LogImportExportView.swift` - Import/export functionality view
- `AboutView.swift` - About and license information view
- `QSORecord.swift` - Persistence controller
- `QSORecordEntity.swift` - QSO record entity definition
- `HamRadioLoggerModel.swift` - Core Data model definition

## Building and Running

1. Ensure you have the latest version of Xcode (13.0 or higher)
2. Clone or download this repository
3. Open the project in Xcode
4. Select an iOS simulator or connected device
5. Click the Run button or press Command+R

## Usage Instructions

### Recording a New QSO
1. Open the app and select the "Record QSO" tab
2. Fill in the callsign (required)
3. Set the date and time
4. Select band and mode
5. Enter frequency (optional)
6. Input signal report
7. Add any additional information
8. Click "Save QSO Record" button

### Querying Logs
1. Select the "Query Log" tab
2. Use the search bar to find specific records
3. Swipe left on records to see edit and delete options

### Import/Export Logs
1. Select the "Import/Export" tab
2. Choose export format (ADIF or CSV)
3. Click "Export All Records"
4. Or select "Import from ADIF File" or "Import from CSV File" to import records

## Localization

EasyQSO supports multiple languages:
- English (en)
- Chinese Simplified (zh-Hans)

All user interface text is localized and can be easily extended to support additional languages.

## License

This project is released under the **GNU General Public License v3.0 (GPLv3)**.

### GPLv3 Key Terms

- **Freedom to Use**: You can freely use this software
- **Freedom to Modify**: You can freely modify the source code
- **Freedom to Distribute**: You can freely distribute this software
- **Source Code Requirement**: If you distribute modified versions, you must also provide the source code
- **Copyright Notice**: Must retain original copyright notice and GPL license

### Complete License Text

For the complete GPLv3 license text, see the [LICENSE](LICENSE) file, or visit the [GNU official website](https://www.gnu.org/licenses/gpl-3.0.html).

### Contributing Code

If you want to contribute code to the project, please ensure your contributions also follow the GPLv3 license. Submitting code means you agree to license your contributions under the GPLv3 terms.

### Contact

For license-related questions, please contact the project maintainer.

## Future Plans

- Add statistical analysis features
- Integrate map display for QTH locations
- Add DXCC entity and award tracking
- Support for cloud synchronization
- Add dark mode support
- Additional language support

## Contributing

We welcome contributions! Please feel free to submit issues, feature requests, or pull requests. When contributing code, please ensure it follows the existing code style and includes appropriate tests.

## Support

If you encounter any issues or have questions, please:
1. Check the existing issues on GitHub
2. Create a new issue with detailed information
3. Contact the development team

## Acknowledgments

- Thanks to all amateur radio operators who provided feedback
- Built with open source technologies and libraries
- Inspired by the amateur radio community's need for better logging tools

---

**EasyQSO** - Making amateur radio logging simple and efficient.
