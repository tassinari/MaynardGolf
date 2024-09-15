//
//  PlayerEntryView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/13/24.
//

import SwiftUI
import SwiftData

extension PlayerEntryView{
    
    enum PlayerEntryError : Error{
        case userExsists
    }
    
    struct ViewModel{
        private var _text : String = ""
        var text : String {
            get{
                return _text
            }
            set{
                _text = newValue
                exsistsError = false
            }
        }
        var exsistsError : Bool = false
        
        func nameExsists(name: String, context : ModelContext) throws -> Bool{
            
            let predicate = #Predicate<Player> { p in
                p.name.localizedStandardContains(name)
            }
            return try context.fetch(FetchDescriptor<Player>(predicate: predicate)).count != 0
            
        }
        
        func addUser( context : ModelContext) throws{
            if text.isEmpty { return }
            if  try nameExsists(name: text, context: context){
                throw PlayerEntryError.userExsists
            }
            do{
            
            let player = Player(name: text)
            context.insert(player)
          
                try context.save()
            }catch let e{
                print(String(describing: e))
            }
        }
        var shouldDenyEntry : Bool{
            
            
            return text.isEmpty
            
        }
        
    }
}

struct PlayerEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var context
    @Query var players: [Player]
    @State var model : ViewModel = ViewModel()
    var body: some View {
        VStack{
            Text("Create a Player")
            TextField("Name", text: $model.text)
            if(model.exsistsError){
                Text("Already Exsists").font(.callout).foregroundStyle(.red)
            }
            
            HStack {
                
             
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Cancel")
                })
                .padding()
                Spacer()
                Button(action: {
                    do{
                        try model.addUser( context: context)
                    }catch PlayerEntryError.userExsists{
                        model.exsistsError = true
                        return
                    }
                    catch{
                        print("error")
                    }
                    
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Create")
                })
                .padding()
                .disabled(model.shouldDenyEntry)
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    PlayerEntryView()
}
