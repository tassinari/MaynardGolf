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
    @State var showRules: Bool = false
    @State var error: Bool = false
    @State var success: Bool = false
    @State var confirmImport: Bool = false
    @State var errorMsg :  String? = nil
    @State var backupURL: ActivityURLData? = nil
    
   
    
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
                            
                            Text("Maynard golf is a free and open source software project. Code and design contributions welcome.")
                                .font(.callout)
                                .foregroundStyle(.gray)
                                .padding(.top, 10)
                            
                            Text("This app is not associated with the Maynard Golf Club in any way.")
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
                    Button("OK", role: .cancel) { }
                    
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
        Section(){
            Button("Local Rules"){
                showRules = true
            }
            
        }
        .sheet(isPresented: $showRules) {
           RuleView()
        }
    }
}

#Preview {
    SettingsView()
}
