import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.secondary)
                    
                    Text("No Sessions Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Complete a Pomodoro session to see your reports here.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .navigationTitle("Reports")
            } else {
                List {
                    ForEach(sessionManager.sessions.sorted(by: { $0.startTime > $1.startTime })) { session in
                        NavigationLink(destination: SessionReportDetailView(session: session)) {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete(perform: sessionManager.deleteSession)
                }
                .navigationTitle("Reports")
                .toolbar {
                    EditButton()
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.formattedDate)
                .font(.headline)
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("\(Int(session.totalWorkDuration / 60)) minutes")
                    .foregroundColor(.secondary)
                
                Image(systemName: "number")
                    .foregroundColor(.secondary)
                Text("\(session.workPeriods.count) periods")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct SessionReportDetailView: View {
    let session: Session
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session metadata
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(session.formattedDate)
                            .font(.headline)
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Total Work Time: \(Int(session.totalWorkDuration / 60)) minutes")
                    }
                    
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.blue)
                        Text("Work Periods: \(session.workPeriods.count)")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // AI Report
                if !session.aiReport.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Report")
                            .font(.headline)
                        
                        Text(session.aiReport)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // Individual work periods
                Text("Work Periods")
                    .font(.headline)
                
                ForEach(Array(session.workPeriods.enumerated()), id: \.element.id) { index, period in
                    WorkPeriodCard(period: period, index: index)
                }
            }
            .padding()
        }
        .navigationTitle("Session Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkPeriodCard: View {
    let period: WorkPeriod
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Period \(index + 1)")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !period.input.isEmpty {
                Text(period.input)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No input recorded")
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            Text("Duration: \(Int(period.duration / 60)) minutes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
} 