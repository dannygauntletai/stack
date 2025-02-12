import SwiftUI

struct ProductReportView: View {
    let report: ProductReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(report.research.summary)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // Key Points Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Points")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(report.research.keyPoints, id: \.self) { point in
                            HStack(alignment: .top) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .padding(.top, 6)
                                Text(point)
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    // Pros & Cons
                    HStack(alignment: .top, spacing: 20) {
                        // Pros
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pros")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            ForEach(report.research.pros, id: \.self) { pro in
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text(pro)
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        
                        // Cons
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cons")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            ForEach(report.research.cons, id: \.self) { con in
                                HStack {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                    Text(con)
                                }
                                .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    
                    // Sources
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sources")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(report.research.sources, id: \.self) { source in
                            Text(source)
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Research Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 