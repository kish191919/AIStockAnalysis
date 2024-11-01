// Services/OpenAIService.swiftimport Foundation
import Foundation

class OpenAIService {
    private let apiKey: String
    
    init() {
        self.apiKey = APIConfig.openAIAPIKey
    }
    
    func analyzeStock(jsonData: String) async throws -> StockAnalysis {
        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Based on this stock data: \(jsonData)

        Please analyze this data and provide:
        1. A clear BULLISH, BEARISH, or NEUTRAL recommendation
        2. Confidence percentage (1-100)
        3. Brief explanation for your recommendation
        4. Expected next day's closing price

        Provide your response in the following JSON format:
        {
            "decision": "BULLISH/BEARISH/NEUTRAL",
            "percentage": <number between 1-100>,
            "reason": "<your analysis>",
            "expected_next_day_price": <predicted price>
        }
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": """
                You are a stock investment expert. Analyze market data using technical indicators and market sentiment.
                Provide analysis in a clear, structured JSON format with a specific decision (BUY/SELL/HOLD),
                confidence level (1-100), reasoning, and next day price prediction.
                """],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.7,
            "max_tokens": 4000
        ]
        
        print("📤 Sending payload to OpenAI")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            print("❌ OpenAI API Error Response: \(String(data: data, encoding: .utf8) ?? "No error data")")
            throw OpenAIError.apiError(message: errorResponse?.error.message ?? "Unknown error")
        }
        
        print("📥 Received response from OpenAI")
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let jsonString = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noResponseContent
        }
        
        print("📝 OpenAI Response Content: \(jsonString)")
        
        // OpenAI 응답을 StockAnalysis 모델로 파싱
        let analysisData = Data(jsonString.utf8)
        return try JSONDecoder().decode(StockAnalysis.self, from: analysisData)
    }
}

extension OpenAIService {
    func getTranslation(prompt: String) async throws -> String {
        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": "You are a professional translator."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw OpenAIError.apiError(message: errorResponse?.error.message ?? "Unknown error")
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noResponseContent
        }
        
        return content
    }
}
