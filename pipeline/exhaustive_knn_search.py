"""Bounded broad, nested development search; no labels/assets changed."""
import argparse
import itertools
import json
import time
import warnings
from pathlib import Path
import numpy as np
from scipy.spatial.distance import cdist
from sklearn.model_selection import GroupKFold
from sklearn.preprocessing import StandardScaler, RobustScaler
from threadpoolctl import threadpool_limits
from exhaustive_color_features import OUT, development_records
from audit_legacy_dataset import ROOT, dump, file_digest
from evaluate_legacy_expansion import trained_predict, cluster_delta, whole
from evaluate_runtime_metric_knn import KEYS, nonregression, rules_nonregression
from improve_direction_verified_knn import measure
from semiquant_schema import ANALYTE_ORDER, ANALYTE_LEVEL_SCHEMA
from audit_abnormal_detection import RULES

LIMIT=threadpool_limits(limits=1)
KS=[1,3,5,7,11]


def fast_metrics(truth,pred,analyte):
    labels=ANALYTE_LEVEL_SCHEMA[analyte];classes=len(labels);n=len(truth)
    matrix=np.bincount(truth*classes+pred,minlength=classes*classes).reshape(classes,classes)
    tp=np.diag(matrix).astype(float);actual=matrix.sum(axis=1);guessed=matrix.sum(axis=0)
    fn=actual-tp;fp=guessed-tp;tn=n-tp-fn-fp
    f1=np.divide(2*tp,2*tp+fn+fp,out=np.zeros(classes),where=(2*tp+fn+fp)>0)
    sensitivity=np.divide(tp,actual,out=np.zeros(classes),where=actual>0)
    specificity=np.divide(tn,n-actual,out=np.zeros(classes),where=(n-actual)>0)
    acc=float(tp.sum()/n);chance=float(actual@guessed/(n*n))
    thresholds={}
    for rule,positive in RULES.get(analyte,{}).items():
        indices=[i for i,c in enumerate(labels) if c in positive]
        pactual=int(actual[indices].sum());ppred=int(guessed[indices].sum())
        ptp=int(matrix[np.ix_(indices,indices)].sum());pfn=pactual-ptp;pfp=ppred-ptp;ptn=n-ptp-pfn-pfp
        thresholds[rule]=dict(sensitivity=ptp/pactual if pactual else None,specificity=ptn/(n-pactual) if n>pactual else None)
    return dict(accuracy=acc,macro_f1_supported_reference_classes=float(f1[actual>0].mean()),
                macro_sensitivity=float(sensitivity[actual>0].mean()),macro_specificity=float(specificity[actual<n].mean()),
                cohens_kappa=(acc-chance)/(1-chance) if chance<1 else None,reference_label_thresholds=thresholds)


def transformed_neighbors(x,augmentation,labels,groups,train,val,geometry,augmented,metric):
    tx=x[train];vx=x[val];y=labels[train];g=groups[train]
    if augmented:
        tx=np.vstack([tx,augmentation[train].reshape(-1,x.shape[1])]);y=np.concatenate([y,np.repeat(y,4)]);g=np.concatenate([g,np.repeat(g,4)])
    scaler=RobustScaler().fit(tx) if geometry=='robust' else StandardScaler().fit(tx)
    tx=scaler.transform(tx);vx=scaler.transform(vx)
    if geometry=='within_class':
        residual=np.vstack([tx[y==c]-tx[y==c].mean(axis=0) for c in np.unique(y)])
        covariance=residual.T@residual/max(1,len(tx)-len(np.unique(y)))
        covariance=.8*covariance+.2*np.diag(np.diag(covariance))+np.eye(tx.shape[1])*.05
        matrix=np.linalg.inv(np.linalg.cholesky(covariance)).T;tx=tx@matrix;vx=vx@matrix
    distance=cdist(vx,tx,metric='cityblock' if metric=='manhattan' else metric)
    order=np.argsort(distance,axis=1,kind='stable')[:,:min(max(KS),len(tx))]
    distances=np.take_along_axis(distance,order,axis=1)
    # Independent-group radius prevents augmented copies calibrating each other.
    reference=cdist(tx,tx,metric='cityblock' if metric=='manhattan' else metric)
    reference[g[:,None]==g[None,:]]=np.inf
    nearest=reference.min(axis=1)
    radius=float(nearest.max()) if np.isfinite(nearest).all() else -1.
    support=distance.min(axis=1)<=radius+1e-10
    counts=np.array([len(set(g[y==c])) for c in range(int(labels.max())+1)],dtype=float)
    return distances,y[order],g[order],np.maximum(counts,1),support


def votes(neighbor_distances,neighbor_labels,neighbor_groups,counts,k,weight,group_balanced,gamma,classes):
    k=min(k,neighbor_distances.shape[1]);d=neighbor_distances[:,:k];y=neighbor_labels[:,:k];g=neighbor_groups[:,:k]
    w=np.ones_like(d) if weight=='uniform' else 1/np.maximum(d,1e-12)
    exact=d<=1e-12
    if weight=='distance':w=np.where(exact.any(axis=1,keepdims=True),exact.astype(float),w)
    if group_balanced:w=w/np.sum(g[:,:,None]==g[:,None,:],axis=2)
    probabilities=np.zeros((len(d),classes))
    for c in range(classes):
        prior = counts[c] if c < len(counts) else 1.
        probabilities[:,c]=np.sum(w*(y==c),axis=1)/prior**gamma
    probabilities/=probabilities.sum(axis=1,keepdims=True)
    prediction=probabilities.argmax(axis=1)
    return prediction,probabilities.max(axis=1)


def objective(value):
    return .45*value['macro_f1_supported_reference_classes']+.30*value['macro_sensitivity']+.15*value['accuracy']+.10*value['macro_specificity']


def acceptance(pred,truth,confidence,support):
    accepted=(confidence>=.55)&support
    return dict(accepted_count=int(accepted.sum()),accepted_accuracy=float((pred[accepted]==truth[accepted]).mean()) if accepted.any() else None)


def search_one(cache,pool,train,old_train,ai,model_spec):
    analyte=ANALYTE_ORDER[ai];schema=ANALYTE_LEVEL_SCHEMA[analyte];classes=len(schema)
    groups=np.array([r['evaluation_group'] for r in pool]);truth=np.array([schema.index(r['labels'][analyte]) for r in pool])
    folds=list(GroupKFold(3).split(train,groups=groups[train]))
    base_pred=np.empty(len(train),dtype=int);base_conf=np.zeros(len(train));base_support=np.zeros(len(train),dtype=bool)
    for tr,va in folds:
        held=set(groups[train[va]]);prior=[r for r in old_train if r['evaluation_group'] not in held]
        values=trained_predict(prior,[pool[i] for i in train[va]],model_spec,ai)
        base_pred[va]=[schema.index(p) for p in values[0]];base_conf[va]=values[1];base_support[va]=values[2]
    base=fast_metrics(truth[train],base_pred,analyte);base_accept=acceptance(base_pred,truth[train],base_conf,base_support)
    keys=[k for k in cache.files if not k.endswith('__aug')];top=[];eligible=[];tested=0
    for recipe in keys:
        x=cache[recipe][:,ai];aug=cache[recipe+'__aug'][:,ai]
        for geometry,metric,augmented in itertools.product(['standard','robust','within_class'],['euclidean','manhattan'],[False,True]):
            neighbors=[]
            for tr,va in folds:
                neighbors.append((va,transformed_neighbors(x,aug,truth,groups,train[tr],train[va],geometry,augmented,metric)))
            for k,weight,balanced,gamma in itertools.product(KS,['uniform','distance'],[False,True],[0.,.25,.5]):
                prediction=np.empty(len(train),dtype=int);confidence=np.zeros(len(train));support=np.zeros(len(train),dtype=bool)
                for va,neighbor in neighbors:
                    prediction[va],confidence[va]=votes(*neighbor[:4],k,weight,balanced,gamma,classes)
                    support[va]=neighbor[4]
                value=fast_metrics(truth[train],prediction,analyte);accepted=acceptance(prediction,truth[train],confidence,support)
                config=dict(recipe=recipe,geometry=geometry,metric=metric,augmentation=augmented,k=k,weights=weight,group_balanced=balanced,prior_gamma=gamma)
                score=dict(config=config,metrics=value,acceptance=accepted,objective=objective(value))
                tested+=1
                if nonregression(base,value) and rules_nonregression(base,value) and value['macro_f1_supported_reference_classes']>base['macro_f1_supported_reference_classes']+1e-12:
                    if accepted['accepted_count']>=base_accept['accepted_count'] and (base_accept['accepted_accuracy'] is None or (accepted['accepted_accuracy'] is not None and accepted['accepted_accuracy']>=base_accept['accepted_accuracy'])):
                        eligible.append(score)
                top.append(score)
                if len(top)>50:top=sorted(top,key=lambda r:r['objective'],reverse=True)[:10]
    # The safe baseline remains a real option when the broad search cannot improve.
    selected=max(eligible,key=lambda r:(r['objective'],r['metrics']['accuracy'],-int(r['config']['augmentation']))) if eligible else dict(config=None,metrics=base,acceptance=base_accept,objective=objective(base))
    return selected,dict(tested=tested,eligible=len(eligible),baseline=base,baseline_acceptance=base_accept,top_diagnostic=sorted(top,key=lambda r:r['objective'],reverse=True)[:10])


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--recovered',action='store_true');args=parser.parse_args()
    cache_dir=OUT/'PRIVATE_EXPANDED' if args.recovered else OUT
    result_dir=OUT/'expanded_search' if args.recovered else OUT/'initial_search';result_dir.mkdir(exist_ok=True)
    assert not (result_dir/'RESULTS.json').exists(), 'Preserve recorded searches'
    cache=np.load(cache_dir/'PRIVATE_COLOR_FEATURES.npz',allow_pickle=False)
    pool,targets,old=development_records(args.recovered)
    ids=json.loads((cache_dir/'PRIVATE_FEATURE_IDENTITIES.json').read_text())
    assert ids['hashes']==[r['image_sha256'] for r in pool]
    assert ids['target_indices']==targets.tolist()
    groups=np.array([r['evaluation_group'] for r in pool]);target_groups=groups[targets]
    model_path=ROOT/'uritect_app/assets/production_semiquant_model.json';model_sha=file_digest(model_path);model=json.loads(model_path.read_text())
    configs_per_analyte=len([k for k in cache.files if not k.endswith('__aug')])*3*2*2*len(KS)*2*2*3
    dump(result_dir/'ANALYSIS_PLAN.json',dict(
        feature_cache_sha256=file_digest(cache_dir/'PRIVATE_COLOR_FEATURES.npz'),search_script_sha256=file_digest(Path(__file__)),
        development_pool=len(pool),paired_validation_photos=len(targets),validation_groups=len(set(target_groups)),
        outer_folds=3,inner_folds=3,settings_per_analyte_per_outer_fold=configs_per_analyte,
        design='Nested grouped development only. Scaling, covariance metric, augmentation and prior/group weighting use training partitions only. Actual known confirmation identities excluded throughout.',
        selection='All five inner-CV metrics, supported clinical-threshold sensitivity/specificity and accepted-reading accuracy/coverage must not regress; macro F1 must improve. Otherwise retain baseline.',
        absolute_support='Maximum leave-one-inferred-group-out nearest training distance, recomputed within each training fold; augmented replicas cannot support their own source group.',
        confidence_threshold=.55,installed_model_sha256=model_sha,reference_labels_changed=False,clinical_validation_established=False))
    shape=(len(targets),10);outputs={name:dict(prediction=np.empty(shape,dtype=object),confidence=np.zeros(shape),support=np.zeros(shape,dtype=bool)) for name in ['baseline','candidate']}
    selections={};folds=list(GroupKFold(3).split(targets,groups=target_groups));start=time.time()
    for ai,analyte in enumerate(ANALYTE_ORDER):
        selections[analyte]=[];spec=model['analytes'][analyte];schema=ANALYTE_LEVEL_SCHEMA[analyte]
        labels=np.array([schema.index(r['labels'][analyte]) for r in pool])
        for fold,(_,va) in enumerate(folds):
            held=set(target_groups[va]);train=np.array([i for i,r in enumerate(pool) if r['evaluation_group'] not in held]);prior=[r for r in old if r['evaluation_group'] not in held]
            val=targets[va]
            assert not set(groups[train])&set(groups[val])
            baseline=trained_predict(prior,[pool[i] for i in val],spec,ai)
            selected,diagnostic=search_one(cache,pool,train,prior,ai,spec)
            config=selected['config']
            if config is None:candidate=baseline
            else:
                recipe=config['recipe'];neighbors=transformed_neighbors(cache[recipe][:,ai],cache[recipe+'__aug'][:,ai],labels,groups,train,val,config['geometry'],config['augmentation'],config['metric'])
                prediction,confidence=votes(*neighbors[:4],config['k'],config['weights'],config['group_balanced'],config['prior_gamma'],len(schema))
                candidate=(np.array(schema)[prediction],confidence,neighbors[4])
            for name,values in [('baseline',baseline),('candidate',candidate)]:
                for key,value in zip(['prediction','confidence','support'],values):outputs[name][key][va,ai]=value
            entry=dict(fold=fold,selected=selected,diagnostic=diagnostic)
            selections[analyte].append(entry)
            dump(result_dir/f'FOLD_{ai:02d}_{fold}.json',entry)
            print(analyte,'fold',fold+1,'/',3,':',diagnostic['tested'],'settings;',diagnostic['eligible'],'eligible;',round(time.time()-start,1),'seconds',flush=True)
    truth=np.array([[pool[i]['labels'][a] for a in ANALYTE_ORDER] for i in targets]);per_analyte={}
    for ai,analyte in enumerate(ANALYTE_ORDER):
        base=measure(truth[:,ai],outputs['baseline']['prediction'][:,ai],target_groups,analyte)
        candidate=measure(truth[:,ai],outputs['candidate']['prediction'][:,ai],target_groups,analyte)
        delta=cluster_delta(truth[:,ai],outputs['baseline']['prediction'][:,ai],outputs['candidate']['prediction'][:,ai],target_groups)
        passed=nonregression(base,candidate) and rules_nonregression(base,candidate) and candidate['macro_f1_supported_reference_classes']>base['macro_f1_supported_reference_classes'] and delta['low']>0
        per_analyte[analyte]=dict(baseline=base,candidate=candidate,accuracy_delta=delta,promotion_screen_passed=passed,fold_selection=selections[analyte])
    whole_scan={name:whole(truth,**values,threshold=.55) for name,values in outputs.items()}
    assert file_digest(model_path)==model_sha
    dump(result_dir/'RESULTS.json',dict(per_analyte=per_analyte,whole_scan=whole_scan,elapsed_seconds=time.time()-start,
        installed_model_unchanged=True,scope='Inspected development only; these are nested selection-procedure results, not confirmation of one frozen deployment recipe.'))
    dump(result_dir/'PRIVATE_PREDICTIONS.json',dict(hashes=[pool[i]['image_sha256'] for i in targets],groups=target_groups.tolist(),truth=truth.tolist(),
        arms={name:{key:value.tolist() for key,value in values.items()} for name,values in outputs.items()}))
    print('Finished broad search. App classifier unchanged.',flush=True)


if __name__=='__main__':main()
