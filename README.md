# AI Stock Analysis App

## Overview
AI Stock Analysis is an iOS application that combines real-time stock market data with AI-powered analysis to provide intelligent investment insights. The app utilizes the GPT-4 model for analyzing market trends and Yahoo Finance API for real-time stock data.

[![Swift Version](https://img.shields.io/badge/Swift-5.0-orange.svg)]()
[![Platform](https://img.shields.io/badge/Platform-iOS%2015.0+-lightgrey.svg)]()

## Features

### Core Functionality
- **Real-time Stock Data**: Integration with Yahoo Finance API for up-to-date market information
- **AI Analysis**: GPT-4 powered market analysis and predictions
- **Interactive Charts**: Dynamic stock price visualization with multiple timeframes
- **Market Sentiment Analysis**: VIX and Fear & Greed Index tracking
- **Multi-language Support**: Analysis available in multiple languages
- **Persistent Storage**: Saves analysis history and user preferences

### Technical Highlights
- SwiftUI-based reactive UI
- MVVM architecture
- Core Data integration for data persistence
- Async/await for network operations
- Combine framework for reactive programming

## Architecture

### Project Structure
```
AIStockAnalysis/
├── App/
│   ├── AIStockAnalysisApp.swift
│   └── ContentView.swift
├── Views/
│   ├── Analysis/
│   │   ├── AnalysisView.swift
│   │   └── Components/
│   ├── Chart/
│   │   └── YahooFinanceChartView.swift
│   └── Common/
├── ViewModels/
│   ├── StockViewModel.swift
│   └── YahooChartViewModel.swift
├── Models/
│   ├── StockData.swift
│   ├── OpenAIModels.swift
│   └── AppLanguage.swift
├── Services/
│   ├── StockService.swift
│   └── OpenAIService.swift
└── Utilities/
```

### Key Components

#### Services
- **StockService**: Handles Yahoo Finance API integration
- **OpenAIService**: Manages GPT-4 API communication

#### ViewModels
- **StockViewModel**: Core business logic and state management
- **YahooChartViewModel**: Chart data processing and visualization

#### Views
- **AnalysisView**: Main analysis interface
- **YahooFinanceChartView**: Interactive stock charts
- **MarketSentimentView**: Market sentiment visualization

## Installation

### Prerequisites
- Xcode 14.0+
- iOS 15.0+
- Active Apple Developer Account
- OpenAI API Key
- Yahoo Finance API Access

### Setup
1. Clone the repository
```bash
git clone https://github.com/yourusername/AIStockAnalysis.git
```

2. Install dependencies (if using CocoaPods/SPM)
```bash
cd AIStockAnalysis
pod install  # If using CocoaPods
```

3. Configure API Keys
- Create `Config.plist` in the project root
- Add your API keys:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>OPENAI_API_KEY</key>
    <string>your-openai-api-key</string>
</dict>
</plist>
```

4. Build and run the project in Xcode

## Usage

### Stock Analysis
1. Enter a stock symbol in the search bar
2. View real-time market data and AI analysis
3. Check different timeframes using the chart controls
4. Access market sentiment indicators

### Settings
- Language selection in the top menu
- Persistent storage of favorite stocks
- Analysis history tracking

## Technical Details

### Data Persistence
The app uses a combination of Core Data and UserDefaults for data persistence:
- Core Data: Analysis history and user data
- UserDefaults: App settings and recent searches

### Network Layer
- URLSession with async/await
- Custom error handling
- Request retry logic

### UI Components
- Custom chart implementation
- Reactive UI updates using Combine
- Adaptive layout for different screen sizes

## Security

### API Key Protection
- API keys stored in Config.plist
- File excluded from git repository
- Runtime encryption for sensitive data

### Data Handling
- Secure storage of user data
- Network security with URLSession
- Error handling and data validation

## Performance

### Optimization Techniques
- Efficient data caching
- Lazy loading of chart data
- Background processing for API calls
- Memory management for large datasets

## Testing

### Unit Tests
- ViewModels testing
- Service layer testing
- Model validation

### UI Tests
- Core user flows
- Edge case handling
- Performance testing

## Troubleshooting

### Common Issues
1. API Connection Issues
   - Check internet connection
   - Verify API key configuration
   - Review request limits

2. Chart Display Problems
   - Clear app cache
   - Check data format
   - Verify timeframe selection

## Contributing
Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details

## Acknowledgments
- OpenAI for GPT-4 API
- Yahoo Finance for market data
- Contributors and maintainers

## Version History
- v1.0.0 (2024-02): Initial release
- v1.1.0 (2024-03): Multi-language support
- v1.2.0 (2024-04): Enhanced chart features

## Contact
For support or queries, please contact [maintainer's email]

---
© 2024 AI Stock Analysis App. All rights reserved.

