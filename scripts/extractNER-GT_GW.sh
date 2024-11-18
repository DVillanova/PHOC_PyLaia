sed 's/</ </g' $1 | sed 's/>/> /g' | awk '{
        pers=0;
	place=0;
	date=0;
	org=0;
	card=0;
        persName="";
	placeName="";
	dateName="";
	orgName="";
	cardName="";
	for (i=2;i<=NF;i++){
		if($i=="<PER>"){
			if(pers==0){ 
			  pers=1;
			}
			else{
			  print persName" </PER>" >> $1".txt";
			  persName="";
			} 
		}
                if($i=="</PER>"){
			pers=0;
			print persName" "$i  >> $1".txt";
			persName="";
		}
                if($i=="<LOCATION>") {
			if(place==0){
			  place=1;
			}
			else{
			  print placeName" </LOCATION>" >> $1".txt";
			  placeName=""; 
			}
		}
                if($i=="</LOCATION>"){
                        place=0;
			print placeName" "$i >> $1".txt";
                        placeName="";
                } 
               if($i=="<DATE>") {
                        if(date==0){
			  date=1;
			}	
                        else{
                          print dateName" </DATE>" >> $1".txt";
                          dateName=""; 
                        }
                }
                if($i=="</DATE>"){
                        date=0;
                        print dateName" "$i >> $1".txt";
                        dateName="";
                } 
               if($i=="<ORGANISATION>") {
                        if(org==0){
			  org=1;
			}
                        else{
                          print orgName" </ORGANISATION>" >> $1".txt";
                          orgName=""; 
                        }
                }
                if($i=="</ORGANISATION>"){
                        org=0;
                        print orgName" "$i >> $1".txt";
                        orgName="";
                } 
				if($i=="<CARDINAL>") {
                        if(card==0){
			  card=1;
			}
                        else{
                          print cardName" </CARDINAL>" >> $1".txt";
                          cardName=""; 
                        }
                }
                if($i=="</CARDINAL>"){
                        card=0;
                        print cardName" "$i >> $1".txt";
                        cardName="";
                } 
		if(pers==1) persName=persName" "$i;
		if(place==1) placeName=placeName" "$i;
		if(date==1) dateName=dateName" "$i;
		if(org==1) orgName=orgName" "$i;
		if(card==1) cardName=cardName" "$i;

	}
	fflush($1".txt")
        close($1".txt")
}' 
