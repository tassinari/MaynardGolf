//
//  SettingsView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/13/24.
//

import SwiftUI
 

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var importing: Bool = false
    @State var backup: Bool = false
    @State var error: Bool = false
    @State var success: Bool = false
    @State var confirmImport: Bool = false
    @State var errorMsg :  String? = nil
    @State var backupURL: ActivityURLData? = nil
    
    let rules: [String] = [
            "USGA Rules govern play unless amended by local rules.",
            "OUT OF BOUNDS: Parking lot, off club property defined by white stakes.",
            "Ball coming to rest in a bark mulch area may be lifted and dropped one club length, no nearer the hole, with no penalty.",
            "All service roads, cart paths, fairway drainage ditches, and protective fences, free lift to nearest point of relief, no nearer the hole.",
            "Ball coming to rest in the confines of a rock or rocks through the green may be moved one club length without penalty.",
            "Players not holding their places on golf course must allow other groups to play through.",
            "Players on 1st tee must alternate with players coming off 9th green.",
            "Do not climb face of bunkers. Rake bunkers and return rake to inside the bunker.",
             "Keep all carts off aprons and greens.",
             "Repair ball marks on green. Replace divots.",
             "Please speed up play.",
             "Maynard Golf Course is a soft spike facility."
        ]
    
    var body: some View {
        NavigationStack{
            VStack{
                List(){
                    
                    Section("Export") {
                        Button {
                            backup = true
                        } label: {
                            Text("Export")
                        }
                        
                        Button("Import") {
                            importing = true
                        }
                        .fileImporter(
                            isPresented: $importing,
                            allowedContentTypes: [.zip]
                        ) { result in
                            switch result {
                            case .success(let file):
                                do{
                                    try ImportExport.importDB(db: file)
                                    success = true
                                    
                                }catch let e{
                                    print(String(describing:e))
                                    errorMsg = e.localizedDescription
                                    error = true
                                }
                                
                            case .failure(let error):
                                print(error.localizedDescription)
                            }
                        }
                    }
                    rulesSection
                    Section("Support"){
                        Link("Open an issue", destination: URL(string: "https://github.com/tassinari/MaynardGolf/issues")!)
                            .font(.body)
                        
                        
                        
                    }
                    
                    Section("About"){
                        VStack(alignment: .leading){
                            Text("Maynard Golf")
                                .font(.headline)
                                .padding([.bottom],5)
                            Text("Version 1.0")
                                .font(.callout)
                                .foregroundStyle(.gray)
                            Text("by Mark Tassinari")
                                .font(.callout)
                                .foregroundStyle(.gray)
                            
                            Text("Maynard golf is a free and open source software project and not associated with Maynard Golf Club.")
                                .font(.callout)
                                .foregroundStyle(.gray)
                                .padding(.top, 10)
                            
                            
                            Text("View on GitHub:")
                                .font(.callout)
                                .foregroundStyle(.gray)
                                .padding(.top)
                            Text("https://github.com/tassinari/MaynardGolf")
                                .font(.callout)
                            
                        }
                        
                    }
                    
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        
                    } label: {
                        Text("Done")
                    }
                }
            }
            .alert("Error", isPresented: $error, presenting: errorMsg, actions: { msg in
                VStack {
                    Text(msg)
                        .font(.body)
                        .padding()
                    
                }
            })
            .alert("The import was successful.", isPresented: $success, actions: {
                Button("OK", role: .cancel) { }
            })
            .sheet(item: $backupURL, content: { urlData in
                ActivityWrapperView(url: urlData.url)
            })
//            .confirmationDialog("This will overwrite your current database. Are you sure?", isPresented: $confirmImport, titleVisibility: .visible) {
//                VStack{
//                    Button("Proceed with Import") {
//                        importing = true
//                    }
//                    .buttonStyle(.destructive)
//                    Button("Proceed with Import") {
//                       //no op
//                    }
//                    .buttonStyle(.cancel)
//                }
//                
//            }
            .confirmationDialog("What type of data?", isPresented: $backup, titleVisibility: .visible) {
                            
                            Button("CSV File") {
                                do{
                                    let url = try ImportExport.zipCSVData()
                                    backupURL = ActivityURLData(url: url)
                                    
                                }
                                catch let e{
                                    errorMsg = e.localizedDescription
                                    error = true
                                }
                            }

                            Button("Full Database") {
                                do{
                                    let url = try ImportExport.zipData()
                                    backupURL = ActivityURLData(url: url)
                                    
                                }
                                catch let e{
                                    errorMsg = e.localizedDescription
                                    error = true
                                }
                               
                            }
                        }
            
        }
       
    }
    var rulesSection : some View{
        Section(header: Text("Local Rules")){
            ForEach(rules, id: \.self){ rule in
                Text(rule)
                    .font(.caption)
                    
            }
        }
    }
}

#Preview {
    SettingsView()
}
