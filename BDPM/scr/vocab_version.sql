--change the dates according to the release date 
bEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'BDPM',
                                          pVocabularyDate        => TO_DATE ('20160721', 'yyyymmdd'),
                                          pVocabularyVersion     => 'dm+d 20160722',
                                          pVocabularyDevSchema   => 'DEV_BDPM');
                                          


                                        
  --do I need to put 'RxNorm Extension' in here?                           
  DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm Extension',
                                          pVocabularyDate        => TO_DATE ('20160721', 'yyyymmdd'),
                                          pVocabularyVersion     => 'RxNorm Extension 20160722',
                                          pVocabularyDevSchema   => 'DEV_BDPM',
                                          pAppendVocabulary      => TRUE);

END;
COMMIT;


